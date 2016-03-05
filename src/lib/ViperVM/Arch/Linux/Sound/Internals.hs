{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DataKinds #-}

module ViperVM.Arch.Linux.Sound.Internals
   ( Cea861AudioInfoFrame (..)
   , AesIec958 (..)
   -- * Hardware dependent: /dev/snd/hw*
   , hwVersion
   , HwInterface (..)
   , HwInfo (..)
   , HwDspStatus (..)
   , HwDspImage (..)
   , ioctlHwVersion
   , ioctlHwInfo
   , ioctlHwDspStatus
   , ioctlHwDspLoad
   -- * PCM: /dev/snd/pcm*
   , pcmVersion
   , PcmClass (..)
   , PcmFormat (..)
   , PcmInfoFlag (..)
   , PcmInfoFlags
   , PcmState (..)
   , PcmInfo (..)
   , PcmHwParam (..)
   , PcmHwParamsFlag (..)
   , PcmHwParamsFlags
   , Mask (..)
   , Interval (..)
   , IntervalOption (..)
   , IntervalOptions
   , PcmHwParams (..)
   , PcmTimeStampMode (..)
   , PcmSwParams (..)
   , PcmChannelInfo (..)
   , PcmAudioTimeStamp (..)
   , PcmStatus (..)
   , PcmMmapStatus (..)
   , PcmMmapControl (..)
   , PcmSyncFlag (..)
   , PcmSyncFlags
   , PcmSyncPtr (..)
   , XferI (..)
   , XferN (..)
   , PcmTimeStampType (..)
   , ChannelPosition (..)
   , ChannelOption (..)
   , ioctlPcmVersion
   , ioctlPcmInfo
   , ioctlPcmTimeStamp
   , ioctlPcmTTimeStamp
   , ioctlPcmHwRefine
   , ioctlPcmHwParams
   , ioctlPcmHwFree
   , ioctlPcmSwParams
   , ioctlPcmStatus
   , ioctlPcmDelay
   , ioctlPcmHwSync
   , ioctlPcmSyncPtr
   , ioctlPcmStatusExt
   , ioctlPcmChannelInfo
   , ioctlPcmPrepare
   , ioctlPcmReset
   , ioctlPcmStart
   , ioctlPcmDrop
   , ioctlPcmDrain
   , ioctlPcmPause
   , ioctlPcmRewind
   , ioctlPcmResume
   , ioctlPcmXRun
   , ioctlPcmForward
   , ioctlPcmWriteIFrames
   , ioctlPcmReadIFrames
   , ioctlPcmWriteNFrames
   , ioctlPcmReadNFrames
   , ioctlPcmLink
   , ioctlPcmUnlink
   )
where

import Data.Word
import Data.Int
import Foreign.Ptr
import Foreign.CStorable
import Foreign.Storable
import Foreign.C.Types (CChar, CSize)
import GHC.Generics (Generic)

import ViperVM.Format.Binary.Vector (Vector)
import ViperVM.Format.Binary.BitSet
import ViperVM.Arch.Linux.Ioctl
import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.FileSystem
import ViperVM.Arch.Linux.FileDescriptor
import ViperVM.Arch.Linux.Time

-- From alsa-lib/include/sound/asound.h

-----------------------------------------------------------------------------
-- Digit audio interface
-----------------------------------------------------------------------------

data AesIec958 = AesIec958
   { aesStatus      :: Vector 24 Word8  -- ^ AES/IEC958 channel status bits
   , aesSubcode     :: Vector 147 Word8 -- ^ AES/IEC958 subcode bits
   , aesPadding     :: CChar            -- ^ nothing
   , aesDigSubFrame :: Vector 4 Word8   -- ^ AES/IEC958 subframe bits
   } deriving (Generic, Show, CStorable)

instance Storable AesIec958 where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf


-----------------------------------------------------------------------------
-- Digit audio interface
-----------------------------------------------------------------------------

data Cea861AudioInfoFrame = Cea861AudioInfoFrame
   { ceaCodingTypeChannelCount :: Word8 -- ^ coding type and channel count
   , ceaSampleFrequencySize    :: Word8 -- ^ sample frequency and size
   , ceaUnused                 :: Word8 -- ^ not used, all zeros
   , ceaChannelAllocationCode  :: Word8 -- ^ channel allocation code
   , ceaDownmixLevelShift      :: Word8 -- ^ downmix inhibit & level-shit values
   } deriving (Generic, Show, CStorable)

instance Storable Cea861AudioInfoFrame where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

-----------------------------------------------------------------------------
-- Section for driver hardware dependent interface - /dev/snd/hw?
-----------------------------------------------------------------------------

hwVersion :: Word32
hwVersion = 0x00010001


data HwInterface
   = HwInterfaceOPL2
   | HwInterfaceOPL3
   | HwInterfaceOPL4
   | HwInterfaceSB16CSP        -- ^ Creative Signal Processor
   | HwInterfaceEMU10K1        -- ^ FX8010 processor in EMU10K1 chip
   | HwInterfaceYSS225         -- ^ Yamaha FX processor
   | HwInterfaceICS2115        -- ^ Wavetable synth
   | HwInterfaceSSCAPE         -- ^ Ensoniq SoundScape ISA card (MC68EC000)
   | HwInterfaceVX             -- ^ Digigram VX cards
   | HwInterfaceMIXART         -- ^ Digigram miXart cards
   | HwInterfaceUSX2Y          -- ^ Tascam US122, US224 & US428 usb
   | HwInterfaceEMUX_WAVETABLE -- ^ EmuX wavetable
   | HwInterfaceBLUETOOTH      -- ^ Bluetooth audio
   | HwInterfaceUSX2Y_PCM      -- ^ Tascam US122, US224 & US428 rawusb pcm
   | HwInterfacePCXHR          -- ^ Digigram PCXHR
   | HwInterfaceSB_RC          -- ^ SB Extigy/Audigy2NX remote control
   | HwInterfaceHDA            -- ^ HD-audio
   | HwInterfaceUSB_STREAM     -- ^ direct access to usb stream
   | HwInterfaceFW_DICE        -- ^ TC DICE FireWire device
   | HwInterfaceFW_FIREWORKS   -- ^ Echo Audio Fireworks based device
   | HwInterfaceFW_BEBOB       -- ^ BridgeCo BeBoB based device
   | HwInterfaceFW_OXFW        -- ^ Oxford OXFW970/971 based device
   | HwInterfaceFW_DIGI00X     -- ^ Digidesign Digi 002/003 family
   | HwInterfaceFW_TASCAM      -- ^ TASCAM FireWire series
   deriving (Show,Eq)

data HwInfo = HwInfo
   { hwInfoDevice    :: Int             -- ^ WR: device number
   , hwInfoCard      :: Int             -- ^ R: card number
   , hwInfoId        :: Vector 64 CChar -- ^ ID (user selectable)
   , hwInfoName      :: Vector 80 CChar -- ^ hwdep name
   , hwInfoInterface :: Int             -- ^ hwdep interface
   , hwInfoReserved  :: Vector 64 Word8 -- ^ reserved for future
   } deriving (Generic, Show, CStorable)

instance Storable HwInfo where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

-- | Generic DSP loader
data HwDspStatus = HwDspStatus
   { hwDspVersion    :: Word            -- ^ R: driver-specific version
   , hwDspId         :: Vector 32 CChar -- ^ R: driver-specific ID string
   , hwDspNumDsps    :: Word            -- ^ R: number of DSP images to transfer
   , hwDspLoadedDsps :: Word            -- ^ R: bit flags indicating the loaded DSPs
   , hwDspChipReady  :: Word            -- ^ R: 1 = initialization finished
   , hwDspReserved   :: Vector 16 Word8 -- ^ reserved for future use
   } deriving (Generic, Show, CStorable)

instance Storable HwDspStatus where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data HwDspImage = HwDspImage
   { hwDspImageIndex      :: Word            -- ^ W: DSP index
   , hwDspImageName       :: Vector 64 CChar -- ^ W: ID (e.g. file name)
   , hwDspImageBin        :: Ptr ()          -- ^ W: binary image
   , hwDspImageLength     :: CSize           -- ^ W: size of image in bytes
   , hwDspImageDriverData :: Word64          -- ^ W: driver-specific data
   } deriving (Generic, Show, CStorable)

instance Storable HwDspImage where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

hwIoctlW :: Storable a => Word8 -> FileDescriptor -> a -> SysRet ()
hwIoctlW n = ioctlWrite sysIoctl 0x48 n defaultCheck

hwIoctlR :: Storable a => Word8 -> FileDescriptor -> SysRet a
hwIoctlR n = ioctlRead sysIoctl 0x48 n defaultCheck

ioctlHwVersion :: FileDescriptor -> SysRet Int
ioctlHwVersion = hwIoctlR 0x00

ioctlHwInfo :: FileDescriptor -> SysRet HwInfo
ioctlHwInfo = hwIoctlR 0x01

ioctlHwDspStatus :: FileDescriptor -> SysRet HwDspStatus
ioctlHwDspStatus = hwIoctlR 0x02

ioctlHwDspLoad :: FileDescriptor -> HwDspImage -> SysRet ()
ioctlHwDspLoad = hwIoctlW 0x03

-----------------------------------------------------------------------------
-- Digital Audio (PCM) interface - /dev/snd/pcm??
-----------------------------------------------------------------------------

pcmVersion :: Word32
pcmVersion = 0x0002000d

data PcmClass
   = PcmClassGeneric  -- ^ standard mono or stereo device
   | PcmClassMulti    -- ^ multichannel device
   | PcmClassModem    -- ^ software modem class
   | PcmClassDigitize -- ^ digitizer class
   deriving (Show,Eq,Enum)


data PcmSubClass
   = PcmSubClassGenericMix -- ^ mono or stereo subdevices are mixed together 
   | PcmSubClassMultiMix   -- ^ multichannel subdevices are mixed together 
   deriving (Show,Eq,Enum)

data PcmStream
   = PcmStreamPlayback
   | PcmStreamCapture
   deriving (Show,Eq,Enum)

data PcmAccess
   = PcmAccessMmapInterleaved     -- ^ interleaved mmap
   | PcmAccessMmapNontInterleaved -- ^ noninterleaved m
   | PcmAccessMmapComplex         -- ^ complex mmap
   | PcmAccessRwInterleaved       -- ^ readi/writei
   | PcmAccessRwNonInterleaved    -- ^ readn/writen
   deriving (Show,Eq,Enum)

data PcmFormat
   = PcmFormatS8
   | PcmFormatU8
   | PcmFormatS16_LE
   | PcmFormatS16_BE
   | PcmFormatU16_LE
   | PcmFormatU16_BE
   | PcmFormatS24_LE -- ^ low three bytes 
   | PcmFormatS24_BE -- ^ low three bytes 
   | PcmFormatU24_LE -- ^ low three bytes 
   | PcmFormatU24_BE -- ^ low three bytes 
   | PcmFormatS32_LE
   | PcmFormatS32_BE
   | PcmFormatU32_LE
   | PcmFormatU32_BE
   | PcmFormatFLOAT_LE   -- ^ 4-byte float, IEEE-754 32-bit, range -1.0 to 1.0 
   | PcmFormatFLOAT_BE   -- ^ 4-byte float, IEEE-754 32-bit, range -1.0 to 1.0 
   | PcmFormatFLOAT64_LE -- ^ 8-byte float, IEEE-754 64-bit, range -1.0 to 1.0 
   | PcmFormatFLOAT64_BE -- ^ 8-byte float, IEEE-754 64-bit, range -1.0 to 1.0 
   | PcmFormatIEC958_SUBFRAME_LE -- ^ IEC-958 subframe, Little Endian 
   | PcmFormatIEC958_SUBFRAME_BE -- ^ IEC-958 subframe, Big Endian 
   | PcmFormatMU_LAW
   | PcmFormatA_LAW
   | PcmFormatIMA_ADPCM
   | PcmFormatMPEG
   | PcmFormatGSM
   | PcmFormatSPECIAL
   | PcmFormatS24_3LE    -- ^ in three bytes 
   | PcmFormatS24_3BE    -- ^ in three bytes 
   | PcmFormatU24_3LE    -- ^ in three bytes 
   | PcmFormatU24_3BE    -- ^ in three bytes 
   | PcmFormatS20_3LE    -- ^ in three bytes 
   | PcmFormatS20_3BE    -- ^ in three bytes 
   | PcmFormatU20_3LE    -- ^ in three bytes 
   | PcmFormatU20_3BE    -- ^ in three bytes 
   | PcmFormatS18_3LE    -- ^ in three bytes 
   | PcmFormatS18_3BE    -- ^ in three bytes 
   | PcmFormatU18_3LE    -- ^ in three bytes 
   | PcmFormatU18_3BE    -- ^ in three bytes 
   | PcmFormatG723_24    -- ^ 8 samples in 3 bytes 
   | PcmFormatG723_24_1B -- ^ 1 sample in 1 byte 
   | PcmFormatG723_40    -- ^ 8 Samples in 5 bytes 
   | PcmFormatG723_40_1B -- ^ 1 sample in 1 byte 
   | PcmFormatDSD_U8     -- ^ DSD, 1-byte samples DSD (x8) 
   | PcmFormatDSD_U16_LE -- ^ DSD, 2-byte samples DSD (x16), little endian 
   | PcmFormatDSD_U32_LE -- ^ DSD, 4-byte samples DSD (x32), little endian 
   | PcmFormatDSD_U16_BE -- ^ DSD, 2-byte samples DSD (x16), big endian 
   | PcmFormatDSD_U32_BE -- ^ DSD, 4-byte samples DSD (x32), big endian 
   deriving (Show,Eq)

instance Enum PcmFormat where
   fromEnum x = case x of
      PcmFormatS8                 -> 0
      PcmFormatU8                 -> 1
      PcmFormatS16_LE             -> 2
      PcmFormatS16_BE             -> 3
      PcmFormatU16_LE             -> 4
      PcmFormatU16_BE             -> 5
      PcmFormatS24_LE             -> 6
      PcmFormatS24_BE             -> 7
      PcmFormatU24_LE             -> 8
      PcmFormatU24_BE             -> 9
      PcmFormatS32_LE             -> 10
      PcmFormatS32_BE             -> 11
      PcmFormatU32_LE             -> 12
      PcmFormatU32_BE             -> 13
      PcmFormatFLOAT_LE           -> 14
      PcmFormatFLOAT_BE           -> 15
      PcmFormatFLOAT64_LE         -> 16
      PcmFormatFLOAT64_BE         -> 17
      PcmFormatIEC958_SUBFRAME_LE -> 18
      PcmFormatIEC958_SUBFRAME_BE -> 19
      PcmFormatMU_LAW             -> 20
      PcmFormatA_LAW              -> 21
      PcmFormatIMA_ADPCM          -> 22
      PcmFormatMPEG               -> 23
      PcmFormatGSM                -> 24
      PcmFormatSPECIAL            -> 31
      PcmFormatS24_3LE            -> 32
      PcmFormatS24_3BE            -> 33
      PcmFormatU24_3LE            -> 34
      PcmFormatU24_3BE            -> 35
      PcmFormatS20_3LE            -> 36
      PcmFormatS20_3BE            -> 37
      PcmFormatU20_3LE            -> 38
      PcmFormatU20_3BE            -> 39
      PcmFormatS18_3LE            -> 40
      PcmFormatS18_3BE            -> 41
      PcmFormatU18_3LE            -> 42
      PcmFormatU18_3BE            -> 43
      PcmFormatG723_24            -> 44
      PcmFormatG723_24_1B         -> 45
      PcmFormatG723_40            -> 46
      PcmFormatG723_40_1B         -> 47
      PcmFormatDSD_U8             -> 48
      PcmFormatDSD_U16_LE         -> 49
      PcmFormatDSD_U32_LE         -> 50
      PcmFormatDSD_U16_BE         -> 51
      PcmFormatDSD_U32_BE         -> 52

   toEnum x = case x of
    0  -> PcmFormatS8
    1  -> PcmFormatU8
    2  -> PcmFormatS16_LE
    3  -> PcmFormatS16_BE
    4  -> PcmFormatU16_LE
    5  -> PcmFormatU16_BE
    6  -> PcmFormatS24_LE
    7  -> PcmFormatS24_BE
    8  -> PcmFormatU24_LE
    9  -> PcmFormatU24_BE
    10 -> PcmFormatS32_LE
    11 -> PcmFormatS32_BE
    12 -> PcmFormatU32_LE
    13 -> PcmFormatU32_BE
    14 -> PcmFormatFLOAT_LE
    15 -> PcmFormatFLOAT_BE
    16 -> PcmFormatFLOAT64_LE
    17 -> PcmFormatFLOAT64_BE
    18 -> PcmFormatIEC958_SUBFRAME_LE
    19 -> PcmFormatIEC958_SUBFRAME_BE
    20 -> PcmFormatMU_LAW
    21 -> PcmFormatA_LAW
    22 -> PcmFormatIMA_ADPCM
    23 -> PcmFormatMPEG
    24 -> PcmFormatGSM
    31 -> PcmFormatSPECIAL
    32 -> PcmFormatS24_3LE
    33 -> PcmFormatS24_3BE
    34 -> PcmFormatU24_3LE
    35 -> PcmFormatU24_3BE
    36 -> PcmFormatS20_3LE
    37 -> PcmFormatS20_3BE
    38 -> PcmFormatU20_3LE
    39 -> PcmFormatU20_3BE
    40 -> PcmFormatS18_3LE
    41 -> PcmFormatS18_3BE
    42 -> PcmFormatU18_3LE
    43 -> PcmFormatU18_3BE
    44 -> PcmFormatG723_24
    45 -> PcmFormatG723_24_1B
    46 -> PcmFormatG723_40
    47 -> PcmFormatG723_40_1B
    48 -> PcmFormatDSD_U8
    49 -> PcmFormatDSD_U16_LE
    50 -> PcmFormatDSD_U32_LE
    51 -> PcmFormatDSD_U16_BE
    52 -> PcmFormatDSD_U32_BE
    _  -> error "Unknown PCM format"

data PcmSubFormat
   = PcmSubFormatStd
   deriving (Show,Eq,Enum)

data PcmInfoFlag
   = PcmInfoMmap                     -- ^ hardware supports mmap
   | PcmInfoMmapValid                -- ^ period data are valid during transfer
   | PcmInfoDouble                   -- ^ Double buffering needed for PCM start/stop
   | PcmInfoBatch                    -- ^ double buffering
   | PcmInfoInterleaved              -- ^ channels are interleaved
   | PcmInfoNonInterleaved           -- ^ channels are not interleaved
   | PcmInfoComplex                  -- ^ complex frame organization (mmap only)
   | PcmInfoBLockTransfer            -- ^ hardware transfer block of samples
   | PcmInfoOverrange                -- ^ hardware supports ADC (capture) overrange detection
   | PcmInfoResume                   -- ^ hardware supports stream resume after suspend
   | PcmInfoPause                    -- ^ pause ioctl is supported
   | PcmInfoHalfDuplex               -- ^ only half duplex
   | PcmInfoJOintDuplex              -- ^ playback and capture stream are somewhat correlated
   | PcmInfoSyncStart                -- ^ pcm support some kind of sync go
   | PcmInfoNoPeriodWakeUp           -- ^ period wakeup can be disabled
   | PcmInfoHasLinkAtime             -- ^ report hardware link audio time, reset on startup
   | PcmInfoHaskLinkAbsoluteAtime    -- ^ report absolute hardware link audio time, not reset on startup
   | PcmInfoHasLinkEstimatedAtime    -- ^ report estimated link audio time
   | PcmInfoHasLinkSynchronizedAtime -- ^ report synchronized audio/system time
   | PcmInfoDrainTrigger             -- ^ internal kernel flag - trigger in drain
   | PcmInfoFifoInFrames             -- ^ internal kernel flag - FIFO size is in frames
   deriving (Show,Eq)

instance Enum PcmInfoFlag where
   fromEnum x = case x of
      PcmInfoMmap                     -> 0
      PcmInfoMmapValid                -> 1
      PcmInfoDouble                   -> 2
      PcmInfoBatch                    -> 4
      PcmInfoInterleaved              -> 8
      PcmInfoNonInterleaved           -> 9
      PcmInfoComplex                  -> 10
      PcmInfoBLockTransfer            -> 16
      PcmInfoOverrange                -> 17
      PcmInfoResume                   -> 18
      PcmInfoPause                    -> 19
      PcmInfoHalfDuplex               -> 20
      PcmInfoJOintDuplex              -> 21
      PcmInfoSyncStart                -> 22
      PcmInfoNoPeriodWakeUp           -> 23
      PcmInfoHasLinkAtime             -> 24
      PcmInfoHaskLinkAbsoluteAtime    -> 25
      PcmInfoHasLinkEstimatedAtime    -> 26
      PcmInfoHasLinkSynchronizedAtime -> 27
      PcmInfoDrainTrigger             -> 30
      PcmInfoFifoInFrames             -> 31
   toEnum x = case x of
      0  -> PcmInfoMmap
      1  -> PcmInfoMmapValid
      2  -> PcmInfoDouble
      4  -> PcmInfoBatch
      8  -> PcmInfoInterleaved
      9  -> PcmInfoNonInterleaved
      10 -> PcmInfoComplex
      16 -> PcmInfoBLockTransfer
      17 -> PcmInfoOverrange
      18 -> PcmInfoResume
      19 -> PcmInfoPause
      20 -> PcmInfoHalfDuplex
      21 -> PcmInfoJOintDuplex
      22 -> PcmInfoSyncStart
      23 -> PcmInfoNoPeriodWakeUp
      24 -> PcmInfoHasLinkAtime
      25 -> PcmInfoHaskLinkAbsoluteAtime
      26 -> PcmInfoHasLinkEstimatedAtime
      27 -> PcmInfoHasLinkSynchronizedAtime
      30 -> PcmInfoDrainTrigger
      31 -> PcmInfoFifoInFrames
      _  -> error "Unknown PCM info flag"

instance EnumBitSet PcmInfoFlag
type PcmInfoFlags = BitSet Word32 PcmInfoFlag


data PcmState
   = PcmStateOpen         -- ^ stream is open
   | PcmStateSetup        -- ^ stream has a setup
   | PcmStatePrepared     -- ^ stream is ready to start
   | PcmStateRunning      -- ^ stream is running
   | PcmStateXRun         -- ^ stream reached an xrun
   | PcmStateDraining     -- ^ stream is draining
   | PcmStatePaused       -- ^ stream is paused
   | PcmStateSuspended    -- ^ hardware is suspended
   | PcmStateDisconnected -- ^ hardware is disconnected
   deriving (Show,Eq,Enum)

instance Storable PcmState where
   sizeOf _    = sizeOf (undefined :: Int)
   alignment _ = alignment (undefined :: Int)
   peek ptr    = toEnum <$> peek (castPtr ptr)
   poke ptr e  = poke (castPtr ptr) (fromEnum e)
instance CStorable PcmState where
   cSizeOf    = sizeOf
   cAlignment = alignment
   cPeek      = peek
   cPoke      = poke

data PcmMmapOffset
   = PcmMmapOffsetData
   | PcmMmapOffsetStatus
   | PcmMmapOffsetControl
   deriving (Show,Eq)

instance Enum PcmMmapOffset where
   fromEnum x = case x of
      PcmMmapOffsetData    -> 0x00000000
      PcmMmapOffsetStatus  -> 0x80000000
      PcmMmapOffsetControl -> 0x81000000
   toEnum x = case x of
      0x00000000 -> PcmMmapOffsetData
      0x80000000 -> PcmMmapOffsetStatus
      0x81000000 -> PcmMmapOffsetControl
      _          -> error "Unknown PCM map offset"

data PcmInfo = PcmInfo
   { pcmInfoDevice               :: Word            -- ^ RO/WR (control): device number
   , pcmInfoSubDevice            :: Word            -- ^ RO/WR (control): subdevice number
   , pcmInfoStream               :: Int             -- ^ RO/WR (control): stream direction
   , pcmInfoCard                 :: Int             -- ^ R: card number
   , pcmInfoID                   :: Vector 64 CChar -- ^ ID (user selectable)
   , pcmInfoName                 :: Vector 80 CChar -- ^ name of this device
   , pcmInfoSubName              :: Vector 32 CChar -- ^ subdevice name
   , pcmInfoDevClass             :: Int             -- ^ SNDRV_PCM_CLASS_*
   , pcmInfoDevSubClass          :: Int             -- ^ SNDRV_PCM_SUBCLASS_*
   , pcmInfoSubDevicesCount      :: Word
   , pcmInfoSubDevicesAvailabled :: Word
   , pcmInfoSync                 :: Vector 16 Word8 -- ^ hardware synchronization ID
   , pcmInfoReserved             :: Vector 64 Word8 -- ^ reserved for future...
   } deriving (Generic, Show, CStorable)

instance Storable PcmInfo where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmHwParam
   = PcmHwParamAccess      -- ^ Access type
   | PcmHwParamFormat      -- ^ Format
   | PcmHwParamSubFormat   -- ^ Subformat
   | PcmHwParamSampleBits  -- ^ Bits per sample 
   | PcmHwParamFrameBits   -- ^ Bits per frame 
   | PcmHwParamChannels    -- ^ Channels 
   | PcmHwParamRate        -- ^ Approx rate 
   | PcmHwParamPeriodTime  -- ^ Approx distance between interrupts in us 
   | PcmHwParamPeriodSize  -- ^ Approx frames between interrupts 
   | PcmHwParamPeriodBytes -- ^ Approx bytes between interrupts 
   | PcmHwParamPeriods     -- ^ Approx interrupts per buffer 
   | PcmHwParamBufferTime  -- ^ Approx duration of buffer in us 
   | PcmHwParamBufferSize  -- ^ Size of buffer in frames 
   | PcmHwParamBufferBytes -- ^ Size of buffer in bytes 
   | PcmHwParamTickTime    -- ^ Approx tick duration in us 
   deriving (Show,Eq)

instance Enum PcmHwParam where
   fromEnum x = case x of
      PcmHwParamAccess      -> 0
      PcmHwParamFormat      -> 1
      PcmHwParamSubFormat   -> 2
      PcmHwParamSampleBits  -> 8
      PcmHwParamFrameBits   -> 9
      PcmHwParamChannels    -> 10
      PcmHwParamRate        -> 11
      PcmHwParamPeriodTime  -> 12
      PcmHwParamPeriodSize  -> 13
      PcmHwParamPeriodBytes -> 14
      PcmHwParamPeriods     -> 15
      PcmHwParamBufferTime  -> 16
      PcmHwParamBufferSize  -> 17
      PcmHwParamBufferBytes -> 18
      PcmHwParamTickTime    -> 19
   toEnum x = case x of
      0  -> PcmHwParamAccess
      1  -> PcmHwParamFormat
      2  -> PcmHwParamSubFormat
      8  -> PcmHwParamSampleBits
      9  -> PcmHwParamFrameBits
      10 -> PcmHwParamChannels
      11 -> PcmHwParamRate
      12 -> PcmHwParamPeriodTime
      13 -> PcmHwParamPeriodSize
      14 -> PcmHwParamPeriodBytes
      15 -> PcmHwParamPeriods
      16 -> PcmHwParamBufferTime
      17 -> PcmHwParamBufferSize
      18 -> PcmHwParamBufferBytes
      19 -> PcmHwParamTickTime
      _  -> error "Unknown PCM HW Param"

data Interval = Interval
   { intervalMin :: Word
   , intervalMax :: Word
   , intervalOptions :: IntervalOptions
   } deriving (Show,Eq,Generic,CStorable)

instance Storable Interval where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data IntervalOption
   = IntervalOpenMin
   | IntervalOpenMax
   | IntervalInteger
   | IntervalEmpty
   deriving (Show,Eq,Enum)

instance EnumBitSet IntervalOption
type IntervalOptions = BitSet Word IntervalOption

data PcmHwParamsFlag
   = PcmHwParamsNoResample     -- ^ avoid rate resampling
   | PcmHwParamsExportBuffer   -- ^ export buffer
   | PcmHwParamsNoPeriodWakeUp -- ^ disable period wakeups
   deriving (Show,Eq,Enum)

instance EnumBitSet PcmHwParamsFlag
type PcmHwParamsFlags = BitSet Word PcmHwParamsFlag

data Mask = Mask
   { maskBits :: Vector 8 Word32
   } deriving (Generic,CStorable,Show)

instance Storable Mask where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmHwParams = PcmHwParams
   { pcmHwParamsFlags               :: PcmHwParamsFlags
   , pcmHwParamsMasks               :: Vector 8 Mask
   , pcmHwParamsIntervals           :: Vector 21 Interval
   , pcmHwParamsRequestedMasks      :: Word               -- ^ W: requested masks
   , pcmHwParamsChangedMasks        :: Word               -- ^ R: changed masks
   , pcmHwParamsInfo                :: Word               -- ^ R: Info flags for returned setup
   , pcmHwParamsMostSignificantBits :: Word               -- ^ R: used most significant bits
   , pcmHwParamsRateNumerator       :: Word               -- ^ R: rate numerator
   , pcmHwParamsRateDenominator     :: Word               -- ^ R: rate denominator
   , pcmHwParamsFifoSize            :: Word64             -- ^ R: chip FIFO size in frames
   , pcmHwParamsReserved            :: Vector 64 Word8    -- ^ reserved for future
   } deriving (Generic, CStorable, Show)

instance Storable PcmHwParams where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf


data PcmTimeStampMode
   = PcmTimeStampNone
   | PcmTimeStampEnabled
   deriving (Show,Eq,Enum)

data PcmSwParams = PcmSwParams
   { pcmSwParamsTimeStamp        :: Int                -- ^ timestamp mode
   , pcmSwParamsPeriodStep       :: Word
   , pcmSwParamsSleepMin         :: Word            -- ^ min ticks to sleep
   , pcmSwParamsAvailMin         :: Word64          -- ^ min avail frames for wakeup
   , pcmSwParamsXFerAlign        :: Word64          -- ^ obsolete: xfer size need to be a multiple
   , pcmSwParamsStartThreshold   :: Word64          -- ^ min hw_avail frames for automatic start
   , pcmSwParamsStopThreshold    :: Word64          -- ^ min avail frames for automatic stop
   , pcmSwParamsSilenceThreshold :: Word64          -- ^ min distance from noise for silence filling
   , pcmSwParamsSilenceSize      :: Word64          -- ^ silence block size
   , pcmSwParamsBoundary         :: Word64          -- ^ pointers wrap point
   , pcmSwParamsProtoVersion     :: Word            -- ^ protocol version
   , pcmSwParamsTimeStampType    :: Word            -- ^ timestamp type (req. proto >= 2.0.12)
   , pcmSwParamsReserved         :: Vector 56 Word8 -- ^ reserved for future
   } deriving (Generic, CStorable, Show)

instance Storable PcmSwParams where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf


data PcmChannelInfo = PcmChannelInfo
   { pcmChannelInfoChannel :: Word
   , pcmChannelInfoOffset  :: Int64 -- ^ mmap offset
   , pcmChannelInfoFirst   :: Word  -- ^ offset to first sample in bits
   , pcmChannelInfoStep    :: Word  -- ^ samples distance in bits
   } deriving (Show,Generic,CStorable)

instance Storable PcmChannelInfo where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmAudioTimeStamp
   = PcmAudioTimeStampCompat           -- ^ For backwards compatibility only, maps to wallclock/link time for HDAudio playback and DEFAULT/DMA time for everything else
   | PcmAudioTimeStampDefault          -- ^ DMA time, reported as per hw_ptr
   | PcmAudioTimeStampLink             -- ^ link time reported by sample or wallclock counter, reset on startup
   | PcmAudioTimeStampLinkAbsolute     -- ^ link time reported by sample or wallclock counter, not reset on startup
   | PcmAudioTimeStampLinkEstimated    -- ^ link time estimated indirectly
   | PcmAudioTimeStampLinkSynchronized -- ^ link time synchronized with system time
   deriving (Show,Eq,Enum)

data PcmStatus = PcmStatus
   { pcmStatusState              :: PcmState        -- ^ stream state
   , pcmStatusTriggerTimeStamp   :: TimeSpec        -- ^ time when stream was started/stopped/paused
   , pcmStatusTimeStamp          :: TimeSpec        -- ^ reference timestamp
   , pcmStatusApplPtr            :: Word64          -- ^ appl ptr
   , pcmStatusHwPtr              :: Word64          -- ^ hw ptr
   , pcmStatusDelay              :: Word64          -- ^ current delay in frames
   , pcmStatusAvail              :: Word64          -- ^ number of frames available
   , pcmStatusAvailMax           :: Word64          -- ^ max frames available on hw since last status
   , pcmStatusOverRange          :: Word64          -- ^ count of ADC (capture) overrange detections from last status
   , pcmStatusSyspendedState     :: PcmState        -- ^ suspended stream state
   , pcmStatusAudioTimeStampData :: Word32          -- ^ needed for 64-bit alignment, used for configs/report to/from userspace
   , pcmStatusAudioTimeStamp     :: TimeSpec        -- ^ sample counter, wall clock, PHC or on-demand sync'ed
   , pcmStatusDriverTimeStamp    :: TimeSpec        -- ^ useful in case reference system tstamp is reported with delay
   , pcmStatusTimeStampAccuracy  :: Word32          -- ^ in ns units, only valid if indicated in audio_tstamp_data
   , pcmStatusReserved           :: Vector 20 Word8 -- ^ must be filled with zero
   } deriving (Show,Generic,CStorable)

instance Storable PcmStatus where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf


data PcmMmapStatus = PcmMmapStatus
   { pcmMmapStatusState          :: PcmState -- ^ RO: state - SNDRV_PCM_STATE_XXXX
   , pcmMmapStatusPadding        :: Int      -- ^ Needed for 64 bit alignment
   , pcmMmapStatusHwPtr          :: Word64   -- ^ RO: hw ptr (0...boundary-1)
   , pcmMmapStatusTimeStamp      :: TimeSpec -- ^ Timestamp
   , pcmMmapStatusSuspendedState :: PcmState -- ^ RO: suspended stream state
   , pcmMmapStatusAudioTimeStamp :: TimeSpec -- ^ from sample counter or wall clock
   } deriving (Show,Generic,CStorable)

instance Storable PcmMmapStatus where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmMmapControl = PcmMmapControl
   { pcmMmapControlApplPtr  :: Word64  -- ^ RW: appl ptr (0...boundary-1)
   , pcmMmapControlAvailMin :: Word64  -- ^ RW: min available frames for wakeup
   } deriving (Show,Generic,CStorable)

instance Storable PcmMmapControl where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmSyncFlag
   = PcmSyncFlagHwSync        -- ^ execute hwsync 
   | PcmSyncFlagPtrAppl       -- ^ get appl_ptr from driver (r/w op) 
   | PcmSyncFlagPtrAvailMin   -- ^ get avail_min from driver 
   deriving (Show,Eq,Enum)

instance EnumBitSet PcmSyncFlag
type PcmSyncFlags = BitSet Word PcmSyncFlag

data PcmSyncPtr = PcmSyncPtr
   { pcmSyncPtrFlags :: PcmSyncFlags
   , pcmSyncPtrStatus :: PcmMmapStatus
   , pcmSyncPtrControl   :: PcmMmapControl
   , pcmSyncPtrPadding :: Vector 48 Word8
   } deriving (Show, Generic, CStorable)

instance Storable PcmSyncPtr where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf


data XferI = XferI
   { xferiResult :: Int64
   , xferiBuffer :: Ptr ()
   , xferiFrames :: Word64
   } deriving (Show, Generic, CStorable)

instance Storable XferI where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data XferN = XferN
   { xfernResult  :: Int64
   , xfernBuffers :: Ptr (Ptr ())
   , xfernFrames  :: Word64
   } deriving (Show, Generic, CStorable)

instance Storable XferN where
   peek      = cPeek
   poke      = cPoke
   alignment = cAlignment
   sizeOf    = cSizeOf

data PcmTimeStampType
   = PcmTimeStampGetTimeOfDay  -- ^ gettimeofday equivalent 
   | PcmTimeStampMonotonic     -- ^ posix_clock_monotonic equivalent 
   | PcmTimeStampMonotonicRaw  -- ^ monotonic_raw (no NTP) 
   deriving (Show,Eq,Enum)


-- | Channel positions
data ChannelPosition
   = ChannelPosUnknown             -- ^ Unknown
   | ChannelPosNA                  -- ^ N/A, silent
   | ChannelPosMono                -- ^ mono stream
   | ChannelPosFrontLeft           -- ^ front left
   | ChannelPosFrontRight          -- ^ front right
   | ChannelPosRearLeft            -- ^ rear left
   | ChannelPosRearRight           -- ^ rear right
   | ChannelPosFrontCenter         -- ^ front center
   | ChannelPosLFE                 -- ^ LFE
   | ChannelPosSideLeft            -- ^ side left
   | ChannelPosSideRight           -- ^ side right
   | ChannelPosRearCenter          -- ^ rear center
   | ChannelPosFrontLeftCenter     -- ^ front left center
   | ChannelPosFrontRightCenter    -- ^ front right center
   | ChannelPosRearLeftCenter      -- ^ rear left center
   | ChannelPosRearRightCenter     -- ^ rear right center
   | ChannelPosFrontLeftWide       -- ^ front left wide
   | ChannelPosFrontRightWide      -- ^ front right wide
   | ChannelPosFrontLeftHigh       -- ^ front left high
   | ChannelPosFrontCenterHigh     -- ^ front center high
   | ChannelPosFrontRightHigh      -- ^ front right high
   | ChannelPosTopCenter           -- ^ top center
   | ChannelPosTopFrontLeft        -- ^ top front left
   | ChannelPosTopFrontRight       -- ^ top front right
   | ChannelPosTopFrontCenter      -- ^ top front center
   | ChannelPosTopRearLeft         -- ^ top rear left
   | ChannelPosTopRearRight        -- ^ top rear right
   | ChannelPosTopRearCenter       -- ^ top rear center
   | ChannelPosTopFrontLeftCenter  -- ^ top front left center
   | ChannelPosTopFrontRightCenter -- ^ top front right center
   | ChannelPosTopSideLeft         -- ^ top side left
   | ChannelPosTopSideRight        -- ^ top side right
   | ChannelPosLeftLFE             -- ^ left LFE
   | ChannelPosRightLFE            -- ^ right LFE
   | ChannelPosBottomCenter        -- ^ bottom center
   | ChannelPosBottomLeftCenter    -- ^ bottom left center
   | ChannelPosBottomRightCenter   -- ^ bottom right center
   deriving (Show,Eq,Enum)

data ChannelOption
   = ChannelPhaseInverse
   | ChannelDriverSpec
   deriving (Show,Eq,EnumBitSet)

instance Enum ChannelOption where
   fromEnum x = case x of
      ChannelPhaseInverse -> 16
      ChannelDriverSpec   -> 17
   toEnum x = case x of
      16 -> ChannelPhaseInverse
      17 -> ChannelDriverSpec
      _  -> error "Unknown channel option"        

pcmIoctl :: Word8 -> FileDescriptor -> SysRet ()
pcmIoctl n = ioctlSignal sysIoctl 0x41 n defaultCheck

pcmIoctlWR :: Storable a => Word8 -> FileDescriptor -> a -> SysRet a
pcmIoctlWR n = ioctlReadWrite sysIoctl 0x41 n defaultCheck

pcmIoctlW :: Storable a => Word8 -> FileDescriptor -> a -> SysRet ()
pcmIoctlW n = ioctlWrite sysIoctl 0x41 n defaultCheck

pcmIoctlR :: Storable a => Word8 -> FileDescriptor -> SysRet a
pcmIoctlR n = ioctlRead sysIoctl 0x41 n defaultCheck

ioctlPcmVersion :: FileDescriptor -> SysRet Int
ioctlPcmVersion = pcmIoctlR 0x00

ioctlPcmInfo :: FileDescriptor -> SysRet PcmInfo
ioctlPcmInfo = pcmIoctlR 0x01

ioctlPcmTimeStamp :: FileDescriptor -> Int -> SysRet ()
ioctlPcmTimeStamp = pcmIoctlW 0x02

ioctlPcmTTimeStamp :: FileDescriptor -> Int -> SysRet ()
ioctlPcmTTimeStamp = pcmIoctlW 0x03

ioctlPcmHwRefine :: FileDescriptor -> PcmHwParams -> SysRet PcmHwParams
ioctlPcmHwRefine = pcmIoctlWR 0x10

ioctlPcmHwParams :: FileDescriptor -> PcmHwParams -> SysRet PcmHwParams
ioctlPcmHwParams = pcmIoctlWR 0x11

ioctlPcmHwFree :: FileDescriptor -> SysRet ()
ioctlPcmHwFree = pcmIoctl 0x12

ioctlPcmSwParams :: FileDescriptor -> PcmSwParams -> SysRet PcmSwParams
ioctlPcmSwParams = pcmIoctlWR 0x13

ioctlPcmStatus :: FileDescriptor -> SysRet PcmStatus
ioctlPcmStatus = pcmIoctlR 0x20

ioctlPcmDelay :: FileDescriptor -> SysRet Int64
ioctlPcmDelay = pcmIoctlR 0x21

ioctlPcmHwSync :: FileDescriptor -> SysRet ()
ioctlPcmHwSync = pcmIoctl 0x22

ioctlPcmSyncPtr :: FileDescriptor -> PcmSyncPtr -> SysRet PcmSyncPtr
ioctlPcmSyncPtr = pcmIoctlWR 0x23

ioctlPcmStatusExt :: FileDescriptor -> PcmStatus -> SysRet PcmStatus
ioctlPcmStatusExt = pcmIoctlWR 0x24

ioctlPcmChannelInfo :: FileDescriptor -> SysRet PcmChannelInfo
ioctlPcmChannelInfo = pcmIoctlR 0x32

ioctlPcmPrepare :: FileDescriptor -> SysRet ()
ioctlPcmPrepare = pcmIoctl 0x40

ioctlPcmReset :: FileDescriptor -> SysRet ()
ioctlPcmReset = pcmIoctl 0x41

ioctlPcmStart :: FileDescriptor -> SysRet ()
ioctlPcmStart = pcmIoctl 0x42

ioctlPcmDrop :: FileDescriptor -> SysRet ()
ioctlPcmDrop = pcmIoctl 0x43

ioctlPcmDrain :: FileDescriptor -> SysRet ()
ioctlPcmDrain = pcmIoctl 0x44

ioctlPcmPause :: FileDescriptor -> Int -> SysRet ()
ioctlPcmPause = pcmIoctlW 0x45

ioctlPcmRewind :: FileDescriptor -> Word64 -> SysRet ()
ioctlPcmRewind = pcmIoctlW 0x46

ioctlPcmResume :: FileDescriptor -> SysRet ()
ioctlPcmResume = pcmIoctl 0x47

ioctlPcmXRun :: FileDescriptor -> SysRet ()
ioctlPcmXRun = pcmIoctl 0x48

ioctlPcmForward :: FileDescriptor -> Word64 -> SysRet ()
ioctlPcmForward = pcmIoctlW 0x49

ioctlPcmWriteIFrames :: FileDescriptor -> XferI -> SysRet ()
ioctlPcmWriteIFrames = pcmIoctlW 0x50

ioctlPcmReadIFrames :: FileDescriptor -> SysRet XferI
ioctlPcmReadIFrames = pcmIoctlR 0x51

ioctlPcmWriteNFrames :: FileDescriptor -> XferN -> SysRet ()
ioctlPcmWriteNFrames = pcmIoctlW 0x52

ioctlPcmReadNFrames :: FileDescriptor -> SysRet XferN
ioctlPcmReadNFrames = pcmIoctlR 0x53

ioctlPcmLink :: FileDescriptor -> Int -> SysRet ()
ioctlPcmLink = pcmIoctlW 0x60

ioctlPcmUnlink :: FileDescriptor -> SysRet ()
ioctlPcmUnlink = pcmIoctl 0x61



{-
/*****************************************************************************
 *                                                                           *
 *                            MIDI v1.0 interface                            *
 *                                                                           *
 *****************************************************************************/

/*
 *  Raw MIDI section - /dev/snd/midi??
 */

#define SNDRV_RAWMIDI_VERSION           SNDRV_PROTOCOL_VERSION(2, 0, 0)

enum {
        SNDRV_RAWMIDI_STREAM_OUTPUT = 0,
        SNDRV_RAWMIDI_STREAM_INPUT,
        SNDRV_RAWMIDI_STREAM_LAST = SNDRV_RAWMIDI_STREAM_INPUT,
};

#define SNDRV_RAWMIDI_INFO_OUTPUT               0x00000001
#define SNDRV_RAWMIDI_INFO_INPUT                0x00000002
#define SNDRV_RAWMIDI_INFO_DUPLEX               0x00000004

struct snd_rawmidi_info {
        unsigned int device;            /* RO/WR (control): device number */
        unsigned int subdevice;         /* RO/WR (control): subdevice number */
        int stream;                     /* WR: stream */
        int card;                       /* R: card number */
        unsigned int flags;             /* SNDRV_RAWMIDI_INFO_XXXX */
        unsigned char id[64];           /* ID (user selectable) */
        unsigned char name[80];         /* name of device */
        unsigned char subname[32];      /* name of active or selected subdevice */
        unsigned int subdevices_count;
        unsigned int subdevices_avail;
        unsigned char reserved[64];     /* reserved for future use */
};

struct snd_rawmidi_params {
        int stream;
        size_t buffer_size;             /* queue size in bytes */
        size_t avail_min;               /* minimum avail bytes for wakeup */
        unsigned int no_active_sensing: 1; /* do not send active sensing byte in close() */
        unsigned char reserved[16];     /* reserved for future use */
};

struct snd_rawmidi_status {
        int stream;
        struct timespec tstamp;         /* Timestamp */
        size_t avail;                   /* available bytes */
        size_t xruns;                   /* count of overruns since last status (in bytes) */
        unsigned char reserved[16];     /* reserved for future use */
};

#define SNDRV_RAWMIDI_IOCTL_PVERSION    _IOR('W', 0x00, int)
#define SNDRV_RAWMIDI_IOCTL_INFO        _IOR('W', 0x01, struct snd_rawmidi_info)
#define SNDRV_RAWMIDI_IOCTL_PARAMS      _IOWR('W', 0x10, struct snd_rawmidi_params)
#define SNDRV_RAWMIDI_IOCTL_STATUS      _IOWR('W', 0x20, struct snd_rawmidi_status)
#define SNDRV_RAWMIDI_IOCTL_DROP        _IOW('W', 0x30, int)
#define SNDRV_RAWMIDI_IOCTL_DRAIN       _IOW('W', 0x31, int)

/*
 *  Timer section - /dev/snd/timer
 */

#define SNDRV_TIMER_VERSION             SNDRV_PROTOCOL_VERSION(2, 0, 6)

enum {
        SNDRV_TIMER_CLASS_NONE = -1,
        SNDRV_TIMER_CLASS_SLAVE = 0,
        SNDRV_TIMER_CLASS_GLOBAL,
        SNDRV_TIMER_CLASS_CARD,
        SNDRV_TIMER_CLASS_PCM,
        SNDRV_TIMER_CLASS_LAST = SNDRV_TIMER_CLASS_PCM,
};

/* slave timer classes */
enum {
        SNDRV_TIMER_SCLASS_NONE = 0,
        SNDRV_TIMER_SCLASS_APPLICATION,
        SNDRV_TIMER_SCLASS_SEQUENCER,           /* alias */
        SNDRV_TIMER_SCLASS_OSS_SEQUENCER,       /* alias */
        SNDRV_TIMER_SCLASS_LAST = SNDRV_TIMER_SCLASS_OSS_SEQUENCER,
};

/* global timers (device member) */
#define SNDRV_TIMER_GLOBAL_SYSTEM       0
#define SNDRV_TIMER_GLOBAL_RTC          1
#define SNDRV_TIMER_GLOBAL_HPET         2
#define SNDRV_TIMER_GLOBAL_HRTIMER      3

/* info flags */
#define SNDRV_TIMER_FLG_SLAVE           (1<<0)  /* cannot be controlled */

struct snd_timer_id {
        int dev_class;
        int dev_sclass;
        int card;
        int device;
        int subdevice;
};

struct snd_timer_ginfo {
        struct snd_timer_id tid;        /* requested timer ID */
        unsigned int flags;             /* timer flags - SNDRV_TIMER_FLG_* */
        int card;                       /* card number */
        unsigned char id[64];           /* timer identification */
        unsigned char name[80];         /* timer name */
        unsigned long reserved0;        /* reserved for future use */
        unsigned long resolution;       /* average period resolution in ns */
        unsigned long resolution_min;   /* minimal period resolution in ns */
        unsigned long resolution_max;   /* maximal period resolution in ns */
        unsigned int clients;           /* active timer clients */
        unsigned char reserved[32];
};

struct snd_timer_gparams {
        struct snd_timer_id tid;        /* requested timer ID */
        unsigned long period_num;       /* requested precise period duration (in seconds) - numerator */
        unsigned long period_den;       /* requested precise period duration (in seconds) - denominator */
        unsigned char reserved[32];
};

struct snd_timer_gstatus {
        struct snd_timer_id tid;        /* requested timer ID */
        unsigned long resolution;       /* current period resolution in ns */
        unsigned long resolution_num;   /* precise current period resolution (in seconds) - numerator */
        unsigned long resolution_den;   /* precise current period resolution (in seconds) - denominator */
        unsigned char reserved[32];
};

struct snd_timer_select {
        struct snd_timer_id id; /* bind to timer ID */
        unsigned char reserved[32];     /* reserved */
};

struct snd_timer_info {
        unsigned int flags;             /* timer flags - SNDRV_TIMER_FLG_* */
        int card;                       /* card number */
        unsigned char id[64];           /* timer identificator */
        unsigned char name[80];         /* timer name */
        unsigned long reserved0;        /* reserved for future use */
        unsigned long resolution;       /* average period resolution in ns */
        unsigned char reserved[64];     /* reserved */
};

#define SNDRV_TIMER_PSFLG_AUTO          (1<<0)  /* auto start, otherwise one-shot */
#define SNDRV_TIMER_PSFLG_EXCLUSIVE     (1<<1)  /* exclusive use, precise start/stop/pause/continue */
#define SNDRV_TIMER_PSFLG_EARLY_EVENT   (1<<2)  /* write early event to the poll queue */

struct snd_timer_params {
        unsigned int flags;             /* flags - SNDRV_MIXER_PSFLG_* */
        unsigned int ticks;             /* requested resolution in ticks */
        unsigned int queue_size;        /* total size of queue (32-1024) */
        unsigned int reserved0;         /* reserved, was: failure locations */
        unsigned int filter;            /* event filter (bitmask of SNDRV_TIMER_EVENT_*) */
        unsigned char reserved[60];     /* reserved */
};

struct snd_timer_status {
        struct timespec tstamp;         /* Timestamp - last update */
        unsigned int resolution;        /* current period resolution in ns */
        unsigned int lost;              /* counter of master tick lost */
        unsigned int overrun;           /* count of read queue overruns */
        unsigned int queue;             /* used queue size */
        unsigned char reserved[64];     /* reserved */
};

#define SNDRV_TIMER_IOCTL_PVERSION      _IOR('T', 0x00, int)
#define SNDRV_TIMER_IOCTL_NEXT_DEVICE   _IOWR('T', 0x01, struct snd_timer_id)
#define SNDRV_TIMER_IOCTL_TREAD         _IOW('T', 0x02, int)
#define SNDRV_TIMER_IOCTL_GINFO         _IOWR('T', 0x03, struct snd_timer_ginfo)
#define SNDRV_TIMER_IOCTL_GPARAMS       _IOW('T', 0x04, struct snd_timer_gparams)
#define SNDRV_TIMER_IOCTL_GSTATUS       _IOWR('T', 0x05, struct snd_timer_gstatus)
#define SNDRV_TIMER_IOCTL_SELECT        _IOW('T', 0x10, struct snd_timer_select)
#define SNDRV_TIMER_IOCTL_INFO          _IOR('T', 0x11, struct snd_timer_info)
#define SNDRV_TIMER_IOCTL_PARAMS        _IOW('T', 0x12, struct snd_timer_params)
#define SNDRV_TIMER_IOCTL_STATUS        _IOR('T', 0x14, struct snd_timer_status)
/* The following four ioctls are changed since 1.0.9 due to confliction */
#define SNDRV_TIMER_IOCTL_START         _IO('T', 0xa0)
#define SNDRV_TIMER_IOCTL_STOP          _IO('T', 0xa1)
#define SNDRV_TIMER_IOCTL_CONTINUE      _IO('T', 0xa2)
#define SNDRV_TIMER_IOCTL_PAUSE         _IO('T', 0xa3)

struct snd_timer_read {
        unsigned int resolution;
        unsigned int ticks;
};

enum {
        SNDRV_TIMER_EVENT_RESOLUTION = 0,       /* val = resolution in ns */
        SNDRV_TIMER_EVENT_TICK,                 /* val = ticks */
        SNDRV_TIMER_EVENT_START,                /* val = resolution in ns */
        SNDRV_TIMER_EVENT_STOP,                 /* val = 0 */
        SNDRV_TIMER_EVENT_CONTINUE,             /* val = resolution in ns */
        SNDRV_TIMER_EVENT_PAUSE,                /* val = 0 */
        SNDRV_TIMER_EVENT_EARLY,                /* val = 0, early event */
        SNDRV_TIMER_EVENT_SUSPEND,              /* val = 0 */
        SNDRV_TIMER_EVENT_RESUME,               /* val = resolution in ns */
        /* master timer events for slave timer instances */
        SNDRV_TIMER_EVENT_MSTART = SNDRV_TIMER_EVENT_START + 10,
        SNDRV_TIMER_EVENT_MSTOP = SNDRV_TIMER_EVENT_STOP + 10,
        SNDRV_TIMER_EVENT_MCONTINUE = SNDRV_TIMER_EVENT_CONTINUE + 10,
        SNDRV_TIMER_EVENT_MPAUSE = SNDRV_TIMER_EVENT_PAUSE + 10,
        SNDRV_TIMER_EVENT_MSUSPEND = SNDRV_TIMER_EVENT_SUSPEND + 10,
        SNDRV_TIMER_EVENT_MRESUME = SNDRV_TIMER_EVENT_RESUME + 10,
};

struct snd_timer_tread {
        int event;
        struct timespec tstamp;
        unsigned int val;
};

/****************************************************************************
 *                                                                          *
 *        Section for driver control interface - /dev/snd/control?          *
 *                                                                          *
 ****************************************************************************/

#define SNDRV_CTL_VERSION               SNDRV_PROTOCOL_VERSION(2, 0, 7)

struct snd_ctl_card_info {
        int card;                       /* card number */
        int pad;                        /* reserved for future (was type) */
        unsigned char id[16];           /* ID of card (user selectable) */
        unsigned char driver[16];       /* Driver name */
        unsigned char name[32];         /* Short name of soundcard */
        unsigned char longname[80];     /* name + info text about soundcard */
        unsigned char reserved_[16];    /* reserved for future (was ID of mixer) */
        unsigned char mixername[80];    /* visual mixer identification */
        unsigned char components[128];  /* card components / fine identification, delimited with one space (AC97 etc..) */
};

typedef int __bitwise snd_ctl_elem_type_t;
#define SNDRV_CTL_ELEM_TYPE_NONE        ((__force snd_ctl_elem_type_t) 0) /* invalid */
#define SNDRV_CTL_ELEM_TYPE_BOOLEAN     ((__force snd_ctl_elem_type_t) 1) /* boolean type */
#define SNDRV_CTL_ELEM_TYPE_INTEGER     ((__force snd_ctl_elem_type_t) 2) /* integer type */
#define SNDRV_CTL_ELEM_TYPE_ENUMERATED  ((__force snd_ctl_elem_type_t) 3) /* enumerated type */
#define SNDRV_CTL_ELEM_TYPE_BYTES       ((__force snd_ctl_elem_type_t) 4) /* byte array */
#define SNDRV_CTL_ELEM_TYPE_IEC958      ((__force snd_ctl_elem_type_t) 5) /* IEC958 (S/PDIF) setup */
#define SNDRV_CTL_ELEM_TYPE_INTEGER64   ((__force snd_ctl_elem_type_t) 6) /* 64-bit integer type */
#define SNDRV_CTL_ELEM_TYPE_LAST        SNDRV_CTL_ELEM_TYPE_INTEGER64

typedef int __bitwise snd_ctl_elem_iface_t;
#define SNDRV_CTL_ELEM_IFACE_CARD       ((__force snd_ctl_elem_iface_t) 0) /* global control */
#define SNDRV_CTL_ELEM_IFACE_HWDEP      ((__force snd_ctl_elem_iface_t) 1) /* hardware dependent device */
#define SNDRV_CTL_ELEM_IFACE_MIXER      ((__force snd_ctl_elem_iface_t) 2) /* virtual mixer device */
#define SNDRV_CTL_ELEM_IFACE_PCM        ((__force snd_ctl_elem_iface_t) 3) /* PCM device */
#define SNDRV_CTL_ELEM_IFACE_RAWMIDI    ((__force snd_ctl_elem_iface_t) 4) /* RawMidi device */
#define SNDRV_CTL_ELEM_IFACE_TIMER      ((__force snd_ctl_elem_iface_t) 5) /* timer device */
#define SNDRV_CTL_ELEM_IFACE_SEQUENCER  ((__force snd_ctl_elem_iface_t) 6) /* sequencer client */
#define SNDRV_CTL_ELEM_IFACE_LAST       SNDRV_CTL_ELEM_IFACE_SEQUENCER

#define SNDRV_CTL_ELEM_ACCESS_READ              (1<<0)
#define SNDRV_CTL_ELEM_ACCESS_WRITE             (1<<1)
#define SNDRV_CTL_ELEM_ACCESS_READWRITE         (SNDRV_CTL_ELEM_ACCESS_READ|SNDRV_CTL_ELEM_ACCESS_WRITE)
#define SNDRV_CTL_ELEM_ACCESS_VOLATILE          (1<<2)  /* control value may be changed without a notification */
#define SNDRV_CTL_ELEM_ACCESS_TIMESTAMP         (1<<3)  /* when was control changed */
#define SNDRV_CTL_ELEM_ACCESS_TLV_READ          (1<<4)  /* TLV read is possible */
#define SNDRV_CTL_ELEM_ACCESS_TLV_WRITE         (1<<5)  /* TLV write is possible */
#define SNDRV_CTL_ELEM_ACCESS_TLV_READWRITE     (SNDRV_CTL_ELEM_ACCESS_TLV_READ|SNDRV_CTL_ELEM_ACCESS_TLV_WRITE)
#define SNDRV_CTL_ELEM_ACCESS_TLV_COMMAND       (1<<6)  /* TLV command is possible */
#define SNDRV_CTL_ELEM_ACCESS_INACTIVE          (1<<8)  /* control does actually nothing, but may be updated */
#define SNDRV_CTL_ELEM_ACCESS_LOCK              (1<<9)  /* write lock */
#define SNDRV_CTL_ELEM_ACCESS_OWNER             (1<<10) /* write lock owner */
#define SNDRV_CTL_ELEM_ACCESS_TLV_CALLBACK      (1<<28) /* kernel use a TLV callback */ 
#define SNDRV_CTL_ELEM_ACCESS_USER              (1<<29) /* user space element */
/* bits 30 and 31 are obsoleted (for indirect access) */

/* for further details see the ACPI and PCI power management specification */
#define SNDRV_CTL_POWER_D0              0x0000  /* full On */
#define SNDRV_CTL_POWER_D1              0x0100  /* partial On */
#define SNDRV_CTL_POWER_D2              0x0200  /* partial On */
#define SNDRV_CTL_POWER_D3              0x0300  /* Off */
#define SNDRV_CTL_POWER_D3hot           (SNDRV_CTL_POWER_D3|0x0000)     /* Off, with power */
#define SNDRV_CTL_POWER_D3cold          (SNDRV_CTL_POWER_D3|0x0001)     /* Off, without power */

#define SNDRV_CTL_ELEM_ID_NAME_MAXLEN   44

struct snd_ctl_elem_id {
        unsigned int numid;             /* numeric identifier, zero = invalid */
        snd_ctl_elem_iface_t iface;     /* interface identifier */
        unsigned int device;            /* device/client number */
        unsigned int subdevice;         /* subdevice (substream) number */
        unsigned char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];              /* ASCII name of item */
        unsigned int index;             /* index of item */
};

struct snd_ctl_elem_list {
        unsigned int offset;            /* W: first element ID to get */
        unsigned int space;             /* W: count of element IDs to get */
        unsigned int used;              /* R: count of element IDs set */
        unsigned int count;             /* R: count of all elements */
        struct snd_ctl_elem_id __user *pids; /* R: IDs */
        unsigned char reserved[50];
};

struct snd_ctl_elem_info {
        struct snd_ctl_elem_id id;      /* W: element ID */
        snd_ctl_elem_type_t type;       /* R: value type - SNDRV_CTL_ELEM_TYPE_* */
        unsigned int access;            /* R: value access (bitmask) - SNDRV_CTL_ELEM_ACCESS_* */
        unsigned int count;             /* count of values */
        __kernel_pid_t owner;           /* owner's PID of this control */
        union {
                struct {
                        long min;               /* R: minimum value */
                        long max;               /* R: maximum value */
                        long step;              /* R: step (0 variable) */
                } integer;
                struct {
                        long long min;          /* R: minimum value */
                        long long max;          /* R: maximum value */
                        long long step;         /* R: step (0 variable) */
                } integer64;
                struct {
                        unsigned int items;     /* R: number of items */
                        unsigned int item;      /* W: item number */
                        char name[64];          /* R: value name */
                        __u64 names_ptr;        /* W: names list (ELEM_ADD only) */
                        unsigned int names_length;
                } enumerated;
                unsigned char reserved[128];
        } value;
        union {
                unsigned short d[4];            /* dimensions */
                unsigned short *d_ptr;          /* indirect - obsoleted */
        } dimen;
        unsigned char reserved[64-4*sizeof(unsigned short)];
};

struct snd_ctl_elem_value {
        struct snd_ctl_elem_id id;      /* W: element ID */
        unsigned int indirect: 1;       /* W: indirect access - obsoleted */
        union {
                union {
                        long value[128];
                        long *value_ptr;        /* obsoleted */
                } integer;
                union {
                        long long value[64];
                        long long *value_ptr;   /* obsoleted */
                } integer64;
                union {
                        unsigned int item[128];
                        unsigned int *item_ptr; /* obsoleted */
                } enumerated;
                union {
                        unsigned char data[512];
                        unsigned char *data_ptr;        /* obsoleted */
                } bytes;
                struct snd_aes_iec958 iec958;
        } value;                /* RO */
        struct timespec tstamp;
        unsigned char reserved[128-sizeof(struct timespec)];
};

struct snd_ctl_tlv {
        unsigned int numid;     /* control element numeric identification */
        unsigned int length;    /* in bytes aligned to 4 */
        unsigned int tlv[0];    /* first TLV */
};

#define SNDRV_CTL_IOCTL_PVERSION        _IOR('U', 0x00, int)
#define SNDRV_CTL_IOCTL_CARD_INFO       _IOR('U', 0x01, struct snd_ctl_card_info)
#define SNDRV_CTL_IOCTL_ELEM_LIST       _IOWR('U', 0x10, struct snd_ctl_elem_list)
#define SNDRV_CTL_IOCTL_ELEM_INFO       _IOWR('U', 0x11, struct snd_ctl_elem_info)
#define SNDRV_CTL_IOCTL_ELEM_READ       _IOWR('U', 0x12, struct snd_ctl_elem_value)
#define SNDRV_CTL_IOCTL_ELEM_WRITE      _IOWR('U', 0x13, struct snd_ctl_elem_value)
#define SNDRV_CTL_IOCTL_ELEM_LOCK       _IOW('U', 0x14, struct snd_ctl_elem_id)
#define SNDRV_CTL_IOCTL_ELEM_UNLOCK     _IOW('U', 0x15, struct snd_ctl_elem_id)
#define SNDRV_CTL_IOCTL_SUBSCRIBE_EVENTS _IOWR('U', 0x16, int)
#define SNDRV_CTL_IOCTL_ELEM_ADD        _IOWR('U', 0x17, struct snd_ctl_elem_info)
#define SNDRV_CTL_IOCTL_ELEM_REPLACE    _IOWR('U', 0x18, struct snd_ctl_elem_info)
#define SNDRV_CTL_IOCTL_ELEM_REMOVE     _IOWR('U', 0x19, struct snd_ctl_elem_id)
#define SNDRV_CTL_IOCTL_TLV_READ        _IOWR('U', 0x1a, struct snd_ctl_tlv)
#define SNDRV_CTL_IOCTL_TLV_WRITE       _IOWR('U', 0x1b, struct snd_ctl_tlv)
#define SNDRV_CTL_IOCTL_TLV_COMMAND     _IOWR('U', 0x1c, struct snd_ctl_tlv)
#define SNDRV_CTL_IOCTL_HWDEP_NEXT_DEVICE _IOWR('U', 0x20, int)
#define SNDRV_CTL_IOCTL_HWDEP_INFO      _IOR('U', 0x21, struct snd_hwdep_info)
#define SNDRV_CTL_IOCTL_PCM_NEXT_DEVICE _IOR('U', 0x30, int)
#define SNDRV_CTL_IOCTL_PCM_INFO        _IOWR('U', 0x31, struct snd_pcm_info)
#define SNDRV_CTL_IOCTL_PCM_PREFER_SUBDEVICE _IOW('U', 0x32, int)
#define SNDRV_CTL_IOCTL_RAWMIDI_NEXT_DEVICE _IOWR('U', 0x40, int)
#define SNDRV_CTL_IOCTL_RAWMIDI_INFO    _IOWR('U', 0x41, struct snd_rawmidi_info)
#define SNDRV_CTL_IOCTL_RAWMIDI_PREFER_SUBDEVICE _IOW('U', 0x42, int)
#define SNDRV_CTL_IOCTL_POWER           _IOWR('U', 0xd0, int)
#define SNDRV_CTL_IOCTL_POWER_STATE     _IOR('U', 0xd1, int)

/*
 *  Read interface.
 */

enum sndrv_ctl_event_type {
        SNDRV_CTL_EVENT_ELEM = 0,
        SNDRV_CTL_EVENT_LAST = SNDRV_CTL_EVENT_ELEM,
};

#define SNDRV_CTL_EVENT_MASK_VALUE      (1<<0)  /* element value was changed */
#define SNDRV_CTL_EVENT_MASK_INFO       (1<<1)  /* element info was changed */
#define SNDRV_CTL_EVENT_MASK_ADD        (1<<2)  /* element was added */
#define SNDRV_CTL_EVENT_MASK_TLV        (1<<3)  /* element TLV tree was changed */
#define SNDRV_CTL_EVENT_MASK_REMOVE     (~0U)   /* element was removed */

struct snd_ctl_event {
        int type;       /* event type - SNDRV_CTL_EVENT_* */
        union {
                struct {
                        unsigned int mask;
                        struct snd_ctl_elem_id id;
                } elem;
                unsigned char data8[60];
        } data;
};

/*
 *  Control names
 */

#define SNDRV_CTL_NAME_NONE                             ""
#define SNDRV_CTL_NAME_PLAYBACK                         "Playback "
#define SNDRV_CTL_NAME_CAPTURE                          "Capture "

#define SNDRV_CTL_NAME_IEC958_NONE                      ""
#define SNDRV_CTL_NAME_IEC958_SWITCH                    "Switch"
#define SNDRV_CTL_NAME_IEC958_VOLUME                    "Volume"
#define SNDRV_CTL_NAME_IEC958_DEFAULT                   "Default"
#define SNDRV_CTL_NAME_IEC958_MASK                      "Mask"
#define SNDRV_CTL_NAME_IEC958_CON_MASK                  "Con Mask"
#define SNDRV_CTL_NAME_IEC958_PRO_MASK                  "Pro Mask"
#define SNDRV_CTL_NAME_IEC958_PCM_STREAM                "PCM Stream"
#define SNDRV_CTL_NAME_IEC958(expl,direction,what)      "IEC958 " expl SNDRV_CTL_NAME_##direction SNDRV_CTL_NAME_IEC958_##what

-}