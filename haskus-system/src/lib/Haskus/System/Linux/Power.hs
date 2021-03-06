{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}

-- | Power-off, reboot, etc.
module Haskus.System.Linux.Power
   ( sysPower
   , disableRebootKeys
   , enableRebootKeys
   , halt
   , executeLoadedKernel
   , powerOff
   , restart
   , restartWithCommand
   , softSuspend
   )
where

import Haskus.System.Linux.Internals.Reboot
import Haskus.System.Linux.Internals.Error
import Haskus.System.Linux.Syscalls
import Haskus.System.Linux.Error
import Haskus.System.Linux.ErrorCode
import Haskus.Format.Binary.Word (Word64)
import Haskus.Format.String (withCString)
import Foreign.Ptr (nullPtr)
import Haskus.Utils.Flow

-- | reboot syscall
sysPower :: MonadInIO m => PowerCommand -> Excepts '[ErrorCode] m ()
sysPower cmd = case cmd of
      PowerRestartCommand cmdPath -> withCString cmdPath f
      _                           -> f nullPtr
   where
      f path = checkErrorCode_ =<< liftIO (syscall_reboot magic1 magic2 cmd' path)
      magic1 = 0xfee1dead :: Word64
      magic2 = 0x28121969 :: Word64
      cmd'   = powerCommandNumber cmd


-- | Ctrl-Alt-Del sequence sends SIGINT to init task.
disableRebootKeys :: MonadInIO m => Excepts '[NotAllowed] m ()
disableRebootKeys = sysPower PowerDisableRebootKeys
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "disableRebootKeys" e

-- | Ctrl-Alt-Del sequence causes RESTART command.
enableRebootKeys :: MonadInIO m => Excepts '[NotAllowed] m ()
enableRebootKeys = sysPower PowerEnableRebootKeys
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "enableRebootKeys" e

-- | Stop OS and give system control to ROM monitor, if any.
halt :: MonadInIO m => Excepts '[NotAllowed] m ()
halt = sysPower PowerHalt
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "halt" e

-- | Restart system using a previously loaded Linux kernel
executeLoadedKernel :: MonadInIO m => Excepts '[NotAllowed] m ()
executeLoadedKernel = sysPower PowerKernelExec
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "executeLoadedKernel" e

-- | Stop OS and remove all power from system, if possible.
powerOff :: MonadInIO m => Excepts '[NotAllowed] m ()
powerOff = sysPower PowerOff
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "powerOff" e

-- | Restart system using default command and mode.
restart :: MonadInIO m => Excepts '[NotAllowed] m ()
restart = sysPower PowerRestart
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "restart" e

-- | Restart system using given command string.
restartWithCommand :: MonadInIO m => String -> Excepts '[NotAllowed,MemoryError,InvalidRestartCommand] m ()
restartWithCommand cmd = sysPower (PowerRestartCommand cmd)
   `catchLiftLeft` \case
      EPERM  -> throwE NotAllowed
      EFAULT -> throwE MemoryError
      EINVAL -> throwE InvalidRestartCommand
      e      -> unhdlErr "restartWithCommand" e

-- | Suspend system using software suspend if compiled in.
softSuspend :: MonadInIO m => Excepts '[NotAllowed] m ()
softSuspend = sysPower PowerSoftSuspend
   `catchLiftBoth` \case
      EPERM -> failureE NotAllowed
      e     -> unhdlErr "softSuspend" e
