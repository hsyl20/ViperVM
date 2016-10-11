{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Byte order ("endianness")
--
-- Indicate in which order bytes are stored in memory for multi-bytes types.
-- Big-endian means that most-significant bytes come first. Little-endian means
-- that least-significant bytes come first.
module ViperVM.Format.Binary.Endianness
   ( Endianness(..)
   , WordGetters (..)
   , WordPutters (..)
   , getWordGetters
   , getWordPutters
   , WordSize (..)
   , ExtendedWordGetters (..)
   , ExtendedWordPutters (..)
   , getExtendedWordGetters
   , getExtendedWordPutters
   , getHostEndianness
   , hostEndianness
   , ByteReversable (..)
   , AsBigEndian (..)
   , AsLittleEndian (..)
   )
where

import ViperVM.Format.Binary.Get
import ViperVM.Format.Binary.Put
import ViperVM.Format.Binary.Enum
import ViperVM.Format.Binary.Ptr
import ViperVM.Format.Binary.Bits ((.|.), shiftL)
import ViperVM.Format.Binary.Storable

import GHC.Word
import Foreign.Storable
import Foreign.CStorable
import System.IO.Unsafe
import Foreign.Marshal.Array
import Foreign.Marshal.Alloc (alloca)

-- | Endianness
data Endianness 
   = LittleEndian    -- ^ Less significant bytes first
   | BigEndian       -- ^ Most significant bytes first
   deriving (Eq,Show,Enum)

instance CEnum Endianness

-- | Word getter
data WordGetters = WordGetters
   { wordGetter8  :: Get Word8   -- ^ Read a Word8
   , wordGetter16 :: Get Word16  -- ^ Read a Word16
   , wordGetter32 :: Get Word32  -- ^ Read a Word132
   , wordGetter64 :: Get Word64  -- ^ Read a Word64
   }

-- | Word putters
data WordPutters = WordPutters
   { wordPutter8  :: Word8  -> Put -- ^ Write a Word8
   , wordPutter16 :: Word16 -> Put -- ^ Write a Word16
   , wordPutter32 :: Word32 -> Put -- ^ Write a Word132
   , wordPutter64 :: Word64 -> Put -- ^ Write a Word64
   }

-- | Get getters for the given endianness
getWordGetters :: Endianness -> WordGetters
getWordGetters e = case e of
   LittleEndian -> WordGetters getWord8 getWord16le getWord32le getWord64le
   BigEndian    -> WordGetters getWord8 getWord16be getWord32be getWord64be

-- | Get putters for the given endianness
getWordPutters :: Endianness -> WordPutters
getWordPutters e = case e of
   LittleEndian -> WordPutters putWord8 putWord16le putWord32le putWord64le
   BigEndian    -> WordPutters putWord8 putWord16be putWord32be putWord64be



-- | Size of a machine word
data WordSize
   = WordSize32      -- ^ 32-bit
   | WordSize64      -- ^ 64-bit
   deriving (Show, Eq)

-- | Extended word getters
data ExtendedWordGetters = ExtendedWordGetters
   { extwordGetter8  :: Get Word8   -- ^ Read a Word8
   , extwordGetter16 :: Get Word16  -- ^ Read a Word16
   , extwordGetter32 :: Get Word32  -- ^ Read a Word132
   , extwordGetter64 :: Get Word64  -- ^ Read a Word64
   , extwordGetterN  :: Get Word64  -- ^ Read a native size word into a Word64
   }

-- | Extended word putters
data ExtendedWordPutters = ExtendedWordPutters
   { extwordPutter8  :: Word8  -> Put -- ^ Write a Word8
   , extwordPutter16 :: Word16 -> Put -- ^ Write a Word16
   , extwordPutter32 :: Word32 -> Put -- ^ Write a Word132
   , extwordPutter64 :: Word64 -> Put -- ^ Write a Word64
   , extwordPutterN  :: Word64 -> Put -- ^ Write a Word64 into a native size word
   }

-- | Return extended getters
getExtendedWordGetters :: Endianness -> WordSize -> ExtendedWordGetters
getExtendedWordGetters endian ws = ExtendedWordGetters gw8 gw16 gw32 gw64 gwN
   where
      WordGetters gw8 gw16 gw32 gw64 = getWordGetters endian
      gwN = case ws of
         WordSize64 -> gw64
         WordSize32 -> fromIntegral <$> gw32

-- | Return extended putters
getExtendedWordPutters :: Endianness -> WordSize -> ExtendedWordPutters
getExtendedWordPutters endian ws = ExtendedWordPutters pw8 pw16 pw32 pw64 pwN
   where
      WordPutters pw8 pw16 pw32 pw64 = getWordPutters endian
      pwN x = case ws of
         WordSize64 -> pw64 x
         WordSize32 -> if x > 0xffffffff
            then error $ "Number too big to be stored in 32-bit word ("++show x++")"
            else pw32 (fromIntegral x)

-- | Detect the endianness of the host memory
getHostEndianness :: IO Endianness
getHostEndianness = do
   -- Write a 32 bit Int and check byte ordering
   let magic = 1 .|. shiftL 8 2 .|. shiftL 16 3 .|. shiftL 24 4 :: Word32
   alloca $ \p -> do
      poke p magic
      rs <- peekArray 4 (castPtr p :: Ptr Word8)
      return $ if rs == [1,2,3,4] then BigEndian else LittleEndian

-- | Detected host endianness
hostEndianness :: Endianness
hostEndianness = unsafePerformIO getHostEndianness

{-# NOINLINE hostEndianness #-}


-- | Reverse bytes in a word
class ByteReversable w where
   reverseBytes       :: w -> w

   hostToBigEndian    :: w -> w
   hostToBigEndian w = case hostEndianness of
      BigEndian    -> w
      LittleEndian -> reverseBytes w

   bigEndianToHost    :: w -> w
   bigEndianToHost w = case hostEndianness of
      BigEndian    -> w
      LittleEndian -> reverseBytes w


   hostToLittleEndian :: w -> w
   hostToLittleEndian w = case hostEndianness of
      BigEndian    -> reverseBytes w
      LittleEndian -> w

   littleEndianToHost :: w -> w
   littleEndianToHost w = case hostEndianness of
      BigEndian    -> reverseBytes w
      LittleEndian -> w

instance ByteReversable Word8 where
   reverseBytes = id

instance ByteReversable Word16 where
   reverseBytes = byteSwap16
                  
instance ByteReversable Word32 where
   reverseBytes = byteSwap32

instance ByteReversable Word64 where
   reverseBytes = byteSwap64



-- | Force a data to be read/stored as big-endian
newtype AsBigEndian a    = AsBigEndian a    deriving (Eq,Ord,Enum,Num,Integral,Real)

instance Show a => Show (AsBigEndian a) where
   show (AsBigEndian a) = show a

-- | Force a data to be read/stored as little-endian
newtype AsLittleEndian a = AsLittleEndian a deriving (Eq,Ord,Enum,Num,Integral,Real)

instance Show a => Show (AsLittleEndian a) where
   show (AsLittleEndian a) = show a

instance (ByteReversable a, FixedStorable a) => FixedStorable (AsBigEndian a) where
   type SizeOf (AsBigEndian a)    = SizeOf a
   type Alignment (AsBigEndian a) = Alignment a

   fixedPeek ptr                 = AsBigEndian . bigEndianToHost <$> fixedPeek (castPtr ptr)
   fixedPoke ptr (AsBigEndian v) = fixedPoke (castPtr ptr) (hostToBigEndian v)


instance (ByteReversable a, Storable a) => Storable (AsBigEndian a) where
   sizeOf _    = sizeOf (undefined :: a)
   alignment _ = alignment (undefined :: a)

   peek ptr                 = AsBigEndian . bigEndianToHost <$> peek (castPtr ptr)
   poke ptr (AsBigEndian v) = poke (castPtr ptr) (hostToBigEndian v)

instance (ByteReversable a, Storable a) => CStorable (AsBigEndian a) where
   cPeek      = peek
   cPoke      = poke
   cSizeOf    = sizeOf
   cAlignment = alignment


   
instance (ByteReversable a, FixedStorable a) => FixedStorable (AsLittleEndian a) where
   type SizeOf (AsLittleEndian a)    = SizeOf a
   type Alignment (AsLittleEndian a) = Alignment a

   fixedPeek ptr                    = AsLittleEndian . bigEndianToHost <$> fixedPeek (castPtr ptr)
   fixedPoke ptr (AsLittleEndian v) = fixedPoke (castPtr ptr) (hostToLittleEndian v)

instance (ByteReversable a, Storable a) => Storable (AsLittleEndian a) where
   sizeOf _    = sizeOf (undefined :: a)
   alignment _ = alignment (undefined :: a)

   peek ptr                 = AsLittleEndian . bigEndianToHost <$> peek (castPtr ptr)
   poke ptr (AsLittleEndian v) = poke (castPtr ptr) (hostToLittleEndian v)

instance (ByteReversable a, Storable a) => CStorable (AsLittleEndian a) where
   cPeek      = peek
   cPoke      = poke
   cSizeOf    = sizeOf
   cAlignment = alignment
