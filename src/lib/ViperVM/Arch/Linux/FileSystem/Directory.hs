{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}


-- | Directory
module ViperVM.Arch.Linux.FileSystem.Directory
   ( sysGetDirectoryEntries
   , sysCreateDirectory
   , sysRemoveDirectory
   , DirectoryEntry(..)
   , DirectoryEntryHeader(..)
   , DirectoryEntryType (..)
   , listDirectory
   )
where

import ViperVM.Format.Binary.BitSet as BitSet
import ViperVM.Format.Binary.Word
import ViperVM.Format.Binary.Enum
import ViperVM.Format.Binary.Ptr
import ViperVM.Format.Binary.Storable
import ViperVM.Format.String

import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.Handle
import ViperVM.Arch.Linux.Syscalls
import ViperVM.Arch.Linux.FileSystem
import ViperVM.Utils.Flow

sysCreateDirectory :: MonadInIO m => Maybe Handle -> FilePath -> FilePermissions -> Bool -> Flow m '[(),ErrorCode]
sysCreateDirectory fd path perm sticky = do
   let
      opt        = if sticky
                     then BitSet.fromList [FileOptSticky]
                     else BitSet.empty
      mode       = makeMode FileTypeDirectory perm opt
      call path' = case fd of
         Nothing           -> liftIO $ syscall @"mkdir" path' mode
         Just (Handle fd') -> liftIO $ syscall @"mkdirat" fd' path' mode

   withCString path call ||> toErrorCodeVoid


sysRemoveDirectory :: MonadInIO m => FilePath -> Flow m '[(),ErrorCode]
sysRemoveDirectory path = withCString path $ \path' ->
   liftIO (syscall @"rmdir" path')
      ||> toErrorCodeVoid


data DirectoryEntryHeader = DirectoryEntryHeader
   { dirInod      :: Word64   -- ^ Inode number
   , dirOffset    :: Int64    -- ^ Offset of the next entry
   , dirLength    :: Word16   -- ^ Length of the entry
   , dirFileTyp   :: Word8    -- ^ Type of file
   } deriving (Show)

$(makeStorable ''DirectoryEntryHeader)

data DirectoryEntry = DirectoryEntry
   { entryInode :: Word64
   , entryType  :: DirectoryEntryType
   , entryName  :: FilePath
   } deriving (Show)

-- | Entry type
--
-- From dirent.h (d_type)
data DirectoryEntryType
   = TypeUnknown
   | TypeFIFO
   | TypeCharDevice
   | TypeDirectory
   | TypeBlockDevice
   | TypeRegularFile
   | TypeSymbolicLink
   | TypeSocket
   | TypeWhiteOut
   deriving (Show,Eq,Enum)

instance CEnum DirectoryEntryType where
   fromCEnum = \case
      TypeUnknown      -> 0
      TypeFIFO         -> 1
      TypeCharDevice   -> 2
      TypeDirectory    -> 4
      TypeBlockDevice  -> 6
      TypeRegularFile  -> 8
      TypeSymbolicLink -> 10
      TypeSocket       -> 12
      TypeWhiteOut     -> 14
   toCEnum = \case
      0  -> TypeUnknown
      1  -> TypeFIFO
      2  -> TypeCharDevice
      4  -> TypeDirectory
      6  -> TypeBlockDevice
      8  -> TypeRegularFile
      10 -> TypeSymbolicLink
      12 -> TypeSocket
      14 -> TypeWhiteOut
      e  -> error ("Invalid DirectoryEntryType: " ++ show (fromIntegral e :: Word8))

-- | getdents64 syscall
--
-- Linux doesn't provide a stateless API: the offset in the file (i.e. the
-- iterator in the directory contents) is shared by everyone using the file
-- descriptor...
--
-- TODO: propose a "pgetdents64" syscall for Linux with an additional offset
-- (like pread, pwrite)
sysGetDirectoryEntries :: MonadInIO m => Handle -> Word -> Flow m '[[DirectoryEntry],ErrorCode]
sysGetDirectoryEntries (Handle fd) buffersize = do

   let
      readEntries p n
         | n < sizeOfT @DirectoryEntryHeader = return []
         | otherwise = do
               hdr  <- peek p
               let 
                  len     = fromIntegral (dirLength hdr)
                  sizede  = sizeOfT @DirectoryEntryHeader
                  namepos = p `indexPtr'` sizede
                  nextpos = p `indexPtr'` len
                  nextlen = n - len
               name <- peekCString (castPtr namepos)
               let x = DirectoryEntry (dirInod hdr) (toCEnum (dirFileTyp hdr)) name
               xs <- readEntries nextpos nextlen
               -- filter deleted files
               if dirInod hdr /= 0
                  then return (x:xs)
                  else return xs

   allocaArray buffersize $ \(ptr :: Ptr Word8) -> do
      liftIO (syscall @"getdents64" fd (castPtr ptr) (fromIntegral buffersize))
         ||> toErrorCode
         >.~.> (\nread -> readEntries (castPtr ptr) (fromIntegral nread))

-- | Return the content of a directory
--
-- Warning: reading concurrently the same file descriptor returns mixed up
-- results because of the stateful kernel interface
listDirectory :: MonadInIO m => Handle -> Flow m '[[DirectoryEntry],ErrorCode]
listDirectory fd = do
      -- Return at the beginning of the directory
      sysSeek' fd 0 SeekSet
      -- Read contents using a given buffer size
      -- If another thread changes the current position in the directory file
      -- descriptor, the returned list can be corrupted (redundant entries or
      -- missing ones)
      >.~^> const (rec [])
   where
      bufferSize = 2 * 1024 * 1024

      -- filter unwanted "directories"
      filtr x = nam /= "." && nam /= ".."
         where nam = entryName x

      rec xs = sysGetDirectoryEntries fd bufferSize
         >.~$> \case
            [] -> flowSetN @0 xs
            ks -> rec (filter filtr ks ++ xs)

