{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances #-}

-- | System info (uname)
module ViperVM.Arch.Linux.Info
   ( SystemInfo(..)
   , systemInfo
   )
where

import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.Syscalls
import ViperVM.Format.Binary.Storable
import ViperVM.Format.Binary.Ptr
import ViperVM.Format.String
import ViperVM.Utils.Flow

-- | struct utsname
data SystemInfo = SystemInfo
   { systemName     :: CStringBuffer 65 -- ^ OS name
   , systemNodeName :: CStringBuffer 65 -- ^ Network name
   , systemRelease  :: CStringBuffer 65 -- ^ Release
   , systemVersion  :: CStringBuffer 65 -- ^ Version
   , systemMachine  :: CStringBuffer 65 -- ^ Hardware identifier
   } deriving (Show)

$(makeStorable ''SystemInfo)

-- | "uname" syscall
systemInfo :: MonadInIO m => Flow m '[SystemInfo,ErrorCode]
systemInfo = alloca $ \(ptr :: Ptr SystemInfo) -> liftIO (syscall @"uname" (castPtr ptr))
      ||>   toErrorCode
      >.~.> (const (peek ptr))
