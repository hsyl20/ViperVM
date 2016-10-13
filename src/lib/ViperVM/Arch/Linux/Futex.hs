{-# LANGUAGE ScopedTypeVariables #-}

-- | Futex (user-space mutex)
module ViperVM.Arch.Linux.Futex
   ( FutexOp(..)
   , sysFutex
   , futexWait
   , futexWake
   , futexRequeue
   , futexCompareRequeue
   )
where

import ViperVM.Format.Binary.Ptr
import ViperVM.Format.Binary.Word
import ViperVM.Format.Binary.Storable
import ViperVM.Format.Binary.Layout.Struct
import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.Syscalls
import ViperVM.Arch.Linux.Time
import ViperVM.Utils.Flow

-- | Futex operation
data FutexOp
   = FutexWait
   | FutexWake
   | FutexFD
   | FutexRequeue
   | FutexCmpRequeue
   deriving (Show,Enum)

-- | All the Futex API uses this `futex` syscall
sysFutex :: Ptr Int64 -> FutexOp -> Int64 -> Ptr (Struct TimeSpec) -> Ptr Int64 -> Int64 -> SysRet Int64
sysFutex uaddr op val timeout uaddr2 val3 =
   onSuccess (syscall_futex uaddr (fromEnum op) val timeout uaddr2 val3) id

-- | Atomically check that addr contains val and sleep until it is wakened up or until the timeout expires
futexWait :: Ptr Int64 -> Int64 -> Maybe TimeSpec -> SysRet ()
futexWait addr val timeout =
   withMaybeOrNull timeout $ \(timeout' :: Ptr (Struct TimeSpec)) ->
      sysFutex addr FutexWait val timeout' nullPtr 0 >.-.> const ()

-- | Wake `count` processes waiting on the futex
--  Return the number of processes woken up
futexWake :: Ptr Int64 -> Int64 -> SysRet Int64
futexWake addr count =
   sysFutex addr FutexWake count nullPtr nullPtr 0


-- | Wake `count` processes waiting on the first futex
-- and requeue the other ones on the second futex.
--
-- Return the number of processes woken up
futexRequeue :: Ptr Int64 -> Int64 -> Ptr Int64 -> SysRet Int64
futexRequeue addr count addr2 =
   sysFutex addr FutexRequeue count nullPtr addr2 0

-- | Atomically compare the first futex with `val, then
-- wake `count` processes waiting on the first futex
-- and requeue the other ones on the second futex.
--
-- Return the number of processes woken up
futexCompareRequeue :: Ptr Int64 -> Int64 -> Int64 -> Ptr Int64 -> SysRet Int64
futexCompareRequeue addr val count addr2 =
   sysFutex addr FutexCmpRequeue count nullPtr addr2 val
