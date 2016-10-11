{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE AllowAmbiguousTypes #-}


-- | Vector with size in the type
module ViperVM.Format.Binary.Vector
   ( Vector (..)
   , vectorBuffer
   , take
   , drop
   , index
   , fromList
   , fromFilledList
   , fromFilledListZ
   , toList
   , replicate
   , concat
   )
where

import GHC.TypeLits
import Data.Proxy
import Foreign.Storable
import Foreign.CStorable
import Foreign.Marshal.Alloc
import Prelude hiding (replicate, head, last,
                       tail, init, map, length, drop, take, concat)
import qualified Data.List as List
import System.IO.Unsafe (unsafePerformIO)

import ViperVM.Utils.HList
import ViperVM.Format.Binary.Storable
import ViperVM.Format.Binary.Ptr
import ViperVM.Format.Binary.Buffer

-- | Vector with type-checked size
data Vector (n :: Nat) a = Vector Buffer

instance (Storable a, Show a, KnownNat n) => Show (Vector n a) where
   show v = "fromList " ++ show (toList v)

-- | Return the buffer backing the vector
vectorBuffer :: Vector n a -> Buffer
vectorBuffer (Vector b) = b

-- | Offset of the i-th element in a stored vector
type family ElemOffset a n where
   ElemOffset a n = n * (SizeOf a)

instance MemoryLayout (Vector n a) where
   type SizeOf (Vector n a)    = ElemOffset a n
   type Alignment (Vector n a) = Alignment a


instance forall a n s.
   ( FixedStorable a
   , s ~ ElemOffset a n
   , KnownNat s
   , KnownNat (SizeOf a)
   ) => FixedStorable (Vector n a) where

   fixedPeek ptr = do
      let sz = natVal (Proxy :: Proxy s)
      Vector <$> bufferPackPtr (fromIntegral sz) (castPtr ptr)

   fixedPoke ptr (Vector b) = bufferPoke ptr b

instance forall a n.
   ( KnownNat n
   , Storable a
   ) => Storable (Vector n a) where
   sizeOf _    = fromIntegral (natVal (Proxy :: Proxy n)) * sizeOf (undefined :: a)
   alignment _ = alignment (undefined :: a)
   peek ptr    = do
      Vector <$> bufferPackPtr (fromIntegral (sizeOf (undefined :: Vector n a))) (castPtr ptr)

   poke ptr (Vector b) = bufferPoke ptr b

instance forall n a.
   ( KnownNat n
   , Storable a
   ) => CStorable (Vector n a) where
   cSizeOf      = sizeOf
   cAlignment   = alignment
   cPeek        = peek
   cPoke        = poke

-- | Yield the first n elements
take :: forall n m a s.
   ( KnownNat n
   , KnownNat m
   , KnownNat s
   , s ~ ElemOffset a n
   )
   => Proxy n -> Vector (m+n) a -> Vector n a
take _ (Vector b) = Vector (bufferTake sz b)
   where
      sz = fromIntegral (natVal (Proxy :: Proxy s))
{-# INLINE take #-}

-- | Drop the first n elements
drop :: forall n m a s.
   ( KnownNat n
   , KnownNat m
   , KnownNat s
   , s ~ ElemOffset a n
   ) => Proxy n -> Vector (m+n) a -> Vector m a
drop _ (Vector b) = Vector (bufferDrop sz b)
   where
      sz = fromIntegral $ natVal (Proxy :: Proxy s)
{-# INLINE drop #-}

-- | /O(1)/ Index safely into the vector using a type level index.
index :: forall a (n :: Nat) (m :: Nat) s.
   ( KnownNat n
   , KnownNat m
   , KnownNat s
   , Storable a
   , CmpNat n m ~ 'LT
   , s ~ ElemOffset a n
   ) => Proxy n -> Vector m a -> a
index _ (Vector b) = bufferPeekStorableAt b off
   where
      off = fromIntegral (natVal (Proxy :: Proxy s))
{-# INLINE index #-}

-- | Convert a list into a vector if the number of elements matches
fromList :: forall a (n :: Nat) .
   ( KnownNat n
   , Storable a
   ) => [a] -> Maybe (Vector n a)
fromList v
   | n' /= n   = Nothing
   | n' == 0   = Just $ Vector $ emptyBuffer
   | otherwise = Just $ Vector $ bufferPackStorableList v
   where
      n' = natVal (Proxy :: Proxy n)
      n  = fromIntegral (List.length v)
{-# INLINE fromList #-}

-- | Take at most n element from the list, then use z
fromFilledList :: forall a (n :: Nat) .
   ( KnownNat n
   , Storable a
   ) => a -> [a] -> Vector n a
fromFilledList z v = Vector $ bufferPackStorableList v'
   where
      v' = List.take n' (v ++ repeat z)
      n' = fromIntegral (natVal (Proxy :: Proxy n))
{-# INLINE fromFilledList #-}

-- | Take at most (n-1) element from the list, then use z
fromFilledListZ :: forall a (n :: Nat) .
   ( KnownNat n
   , Storable a
   ) => a -> [a] -> Vector n a
fromFilledListZ z v = fromFilledList z v'
   where
      v' = List.take (n'-1) v
      n' = fromIntegral (natVal (Proxy :: Proxy n))
{-# INLINE fromFilledListZ #-}

-- | Convert a vector into a list
toList :: forall a (n :: Nat) .
   ( KnownNat n
   , Storable a
   ) => Vector n a -> [a]
toList (Vector b)
   | n == 0    = []
   | otherwise = fmap (bufferPeekStorableAt b . (sza*)) [0..n-1]
   where
      n   = fromIntegral (natVal (Proxy :: Proxy n))
      sza = fromIntegral (sizeOf (undefined :: a))
{-# INLINE toList #-}

-- | Create a vector by replicating a value
replicate :: forall a (n :: Nat) .
   ( KnownNat n
   , Storable a
   ) => a -> Vector n a
replicate v = fromFilledList v []
{-# INLINE replicate #-}


data StoreVector = StoreVector -- Store a vector at the right offset

instance forall (n :: Nat) v a r s.
   ( v ~ Vector n a
   , r ~ IO (Ptr a)
   , KnownNat n
   , KnownNat (SizeOf a)
   , s ~ ElemOffset a n
   , KnownNat s
   , FixedStorable a
   , Storable a
   ) => Apply StoreVector (v, IO (Ptr a)) r where
      apply _ (v, getP) = do
         p <- getP
         let
            vsz = fromIntegral (natVal (Proxy :: Proxy n))
            p'  = p `indexPtr` (-1 * vsz * sizeOf (undefined :: a))
         poke (castPtr p') v 
         return p'

type family WholeSize fs :: Nat where
   WholeSize '[]                 = 0
   WholeSize (Vector n s ': xs)  = n + WholeSize xs

-- | Concat several vectors into a single one
concat :: forall l (n :: Nat) a .
   ( n ~ WholeSize l
   , KnownNat n
   , Storable a
   , FixedStorable a
   , HFoldr StoreVector (IO (Ptr a)) l (IO (Ptr a))
   )
   => HList l -> Vector n a
concat vs = unsafePerformIO $ do
   let sz = sizeOf (undefined :: a) * fromIntegral (natVal (Proxy :: Proxy n))
   p <- mallocBytes sz :: IO (Ptr ())
   _ <- hFoldr StoreVector (return (castPtr p `indexPtr` sz) :: IO (Ptr a)) vs :: IO (Ptr a)
   Vector <$> bufferUnsafePackPtr (fromIntegral sz) p
