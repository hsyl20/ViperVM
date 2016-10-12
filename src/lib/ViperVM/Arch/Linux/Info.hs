{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}

-- | System info (uname)
module ViperVM.Arch.Linux.Info
   ( SystemInfo(..)
   , systemInfo
   )
where

import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.Syscalls
import ViperVM.Format.Binary.Word
import ViperVM.Format.Binary.Ptr
import ViperVM.Format.String
import ViperVM.Utils.Types.Generics

-- | struct utsname
data SystemInfo = SystemInfo
   { systemName     :: CStringBuffer 65
   , systemNodeName :: CStringBuffer 65
   , systemRelease  :: CStringBuffer 65
   , systemVersion  :: CStringBuffer 65
   , systemMachine  :: CStringBuffer 65
   } deriving (Show,Generic)

-- | "uname" syscall
systemInfo :: SysRet SystemInfo
systemInfo = alloca $ \ptr -> onSuccessIO (uname ptr) (const (peek ptr))
   where
      uname :: Ptr SystemInfo -> IO Int64
      uname = syscall_uname . castPtr
