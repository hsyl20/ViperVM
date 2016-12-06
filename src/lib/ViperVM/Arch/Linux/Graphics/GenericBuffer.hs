-- | Generic buffer management
--
-- Generic buffers are unaccelerated buffers that can be used with all devices
-- that support them with the same API (contrary to accelerated buffers)
--
-- Generic buffers are called "dumb buffers" in original terminology
--
module ViperVM.Arch.Linux.Graphics.GenericBuffer
   ( GenericBuffer
   , GenericBufferMap
   , createGenericBuffer
   , destroyGenericBuffer
   , mapGenericBuffer
   )
where

import ViperVM.Arch.Linux.ErrorCode
import ViperVM.Arch.Linux.Handle
import ViperVM.Arch.Linux.Internals.Graphics
import ViperVM.Utils.Flow
import ViperVM.Format.Binary.Word

type GenericBuffer = StructCreateDumb
type GenericBufferMap = StructMapDumb

-- | Create a generic buffer
createGenericBuffer :: MonadIO m => Handle -> Word32 -> Word32 -> Word32 -> Word32 -> Flow m '[GenericBuffer,ErrorCode]
createGenericBuffer hdl width height bpp flags = do
   let s = StructCreateDumb height width bpp flags 0 0 0
   liftIO (ioctlCreateGenericBuffer s hdl)

-- | Destroy a generic buffer
destroyGenericBuffer :: MonadIO m => Handle -> GenericBuffer -> Flow m '[(),ErrorCode]
destroyGenericBuffer hdl buffer = do
   let s = StructDestroyDumb (cdHandle buffer)
   liftIO (ioctlDestroyGenericBuffer s hdl) >.-.> const ()

-- | Map a Generic buffer
mapGenericBuffer :: MonadIO m => Handle -> GenericBuffer -> Flow m '[GenericBufferMap,ErrorCode]
mapGenericBuffer hdl buffer = do
   let s = StructMapDumb (cdHandle buffer) 0 0
   liftIO (ioctlMapGenericBuffer s hdl)
