{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE MultiWayIf #-}

module Haskus.Format.Binary.Unum2
   ( Unum (..)
   , UnumWord
   , unumNegate
   , unumReciprocate
   , unumIsOpenInterval
   , unumIsExactNumber
   , unumBitCount
   , toUnum
   , fromUnum
   , rcp
   -- * Set of real numbers (SORN)
   , SORN (..)
   , SORNSize
   , sornElems
   , sornEmpty
   , sornInsert
   , sornRemove
   , sornFromList
   -- * Numeric systems
   , Unum2b (..)
   , Unum3b (..)
   )
where

import Data.Set as Set
import GHC.Real
import Haskus.Format.Binary.Word
import Haskus.Format.Binary.Bits
import Haskus.Utils.Types
import Haskus.Utils.Flow
import Haskus.Utils.List as List

type family UnumWord x where
   UnumWord x = WordAtLeast (UnumBitCount x)

-- | Numeric system
class Unum x where
   -- | Number of bits to store a number
   type UnumBitCount x :: Nat

   -- | Pack a number
   unumPack :: UnumWord x -> x

   -- | Unpack a number
   unumUnpack :: x -> UnumWord x

   -- Strictly positive exact members of the numeric system without their reciprocals
   --
   -- We then include the inverse and the reciprocal of every number (0
   -- and its reciprocal are included too)
   unumInputMembers :: x -> Set Rational

   -- | All the exact members of the numeric system (including `infinity`)
   unumExactMembers :: x -> Set Rational
   unumExactMembers x = Set.unions
      [ unumPositiveMembers x
      , unumNegativeMembers x
      , Set.singleton 0
      , Set.singleton infinity
      ]

   -- | Positive members
   unumPositiveMembers :: x -> Set Rational
   unumPositiveMembers x = Set.unions
      [ unumInputMembers x
      , Set.map rcp (unumInputMembers x)
      ]

   -- | Negative members
   unumNegativeMembers :: x -> Set Rational
   unumNegativeMembers = Set.map (0 -) . unumPositiveMembers

 
-- | Reciprocate
rcp :: Rational -> Rational
rcp (n :% d) = d :% n

unumIsOpenInterval :: 
   ( FiniteBits (UnumWord u)
   , Unum u
   ) => u -> Bool
{-# INLINE unumIsOpenInterval #-}
unumIsOpenInterval u = testBit (unumUnpack u) 0

unumIsExactNumber ::
   ( FiniteBits (UnumWord u)
   , Unum u
   ) => u -> Bool
{-# INLINE unumIsExactNumber #-}
unumIsExactNumber = not . unumIsOpenInterval

unumBitCount :: forall u. (KnownNat (UnumBitCount u)) => Word
unumBitCount = natValue @(UnumBitCount u)

-- | Negate a number
unumNegate :: forall u.
   ( FiniteBits (UnumWord u)
   , Num (UnumWord u)
   , KnownNat (UnumBitCount u)
   , Unum u
   ) => u -> u
{-# INLINE unumNegate #-}
unumNegate u =
   unumPack
   <| maskLeastBits (unumBitCount @u)
   <| complement (unumUnpack u) + 1

-- | Reciprocate a number
unumReciprocate :: forall u.
   ( FiniteBits (UnumWord u)
   , Num (UnumWord u)
   , KnownNat (UnumBitCount u)
   , Unum u
   ) => u -> u
{-# INLINE unumReciprocate #-}
unumReciprocate u =
   unumPack
   <| (unumUnpack u `xor` m + 1)
   where
      s = unumBitCount @u
      m = makeMask (s-1)

-- | Build a number from a Rational
toUnum :: forall u.
   ( Unum u
   , FiniteBits (UnumWord u)
   , Num (UnumWord u)
   , KnownNat (UnumBitCount u)
   ) => Rational -> u
toUnum x
   | x < 0     = unumNegate      (toUnum (0 - x))
   | x == 0    = unumPack 0
   | x < 1     = unumReciprocate (toUnum (rcp x))
   | otherwise = case go 0 x es of
         (b,certain) -> unumPack ((b `shiftL` 1) .|. if certain then 0 else 1)
      where
         es = 0 : Set.toAscList (unumPositiveMembers (undefined :: u))

         go _ _ []         = error "toUnum: empty member list"
         go i b [x1]       = if b == x1 then (i,True) else (i,False)
         go i b (x1:x2:xs) = if
            | b < x1    -> error "toUnum: invalid number"
            | b == x1   -> (i,True)
            | b < x2    -> (i,False)
            | otherwise -> go (i+1) b (x2:xs)

-- | Return a Rational and the uncertainty bit from a number
--
-- TODO: currently we use Set.elemAt which is O(log n). We may want to use an
-- O(1) array generated statically if possible.
fromUnum :: forall u.
   ( Unum u
   , FiniteBits (UnumWord u)
   , Integral (UnumWord u)
   , KnownNat (UnumBitCount u)
   ) => u -> (Rational,Bool)
fromUnum u = (r, unumIsExactNumber u)
   where
      w = unumUnpack u `shiftR` 1
      signed = testBit w (fromIntegral (unumBitCount @u - 2))
      i      = fromIntegral <| clearBit w (fromIntegral (unumBitCount @u - 2))
      r = if
         | signed && i == 0 -> infinity
         |           i == 0 -> 0
         | signed           -> Set.elemAt (i-1) (unumNegativeMembers (undefined :: u))
         | otherwise        -> Set.elemAt (i-1) (unumPositiveMembers (undefined :: u))
   
-------------------------------------------------
-- SORNs

-- | Set of Real Numbers (SORN)
newtype SORN u = SORN (SORNWord u)

instance Eq (SORNWord u) => Eq (SORN u) where
   (==) (SORN a) (SORN b) = a == b

instance Ord (SORNWord u) => Ord (SORN u) where
   compare (SORN a) (SORN b) = compare a b

instance
   ( Show u
   , Unum u
   , KnownNat (UnumBitCount u)
   , Num (UnumWord u)
   , FiniteBits (UnumWord u)
   , Eq (SORNWord u)
   , FiniteBits (SORNWord u)
   ) => Show (SORN u)
   where
      show su = "fromList " ++ show (sornElems su)

type family SORNSize u where
   SORNSize u = Pow 2 (UnumBitCount u)

type family SORNWord u where
   SORNWord u = WordAtLeast (SORNSize u)

-- | Return SORN elements
sornElems :: forall u.
   ( Unum u
   , KnownNat (UnumBitCount u)
   , Num (UnumWord u)
   , Eq (SORNWord u)
   , FiniteBits (SORNWord u)
   ) => SORN u -> [u]
sornElems (SORN su) = go su
   where
      go w
         | w == zeroBits = []
         | otherwise     = unumPack w' : go (clearBit w c)
            where
               w' = fromIntegral c :: UnumWord u
               c = countTrailingZeros w

-- | Empty SORN
sornEmpty ::
   ( Unum u
   , FiniteBits (SORNWord u)
   ) => SORN u
sornEmpty = SORN zeroBits

-- | Insert element into a SORN
sornInsert ::
   ( Unum u
   , FiniteBits (SORNWord u)
   , Integral (UnumWord u)
   ) => SORN u -> u -> SORN u
sornInsert (SORN w) u = SORN (setBit w (fromIntegral (unumUnpack u)))

-- | Remove element into a SORN
sornRemove ::
   ( Unum u
   , FiniteBits (SORNWord u)
   , Integral (UnumWord u)
   ) => SORN u -> u -> SORN u
sornRemove (SORN w) u = SORN (clearBit w (fromIntegral (unumUnpack u)))

-- | Create a SORN from a list
sornFromList ::
   ( Unum u
   , Integral (UnumWord u)
   , FiniteBits (SORNWord u)
   ) => [u] -> SORN u
sornFromList = List.foldl' sornInsert sornEmpty 

-------------------------------------------------
-- Default numeric systems

-- | 2-bit Unum
newtype Unum2b = Unum2b Word8 deriving (Show,Eq,Ord)

instance Unum Unum2b where
   type UnumBitCount Unum2b = 2
   unumPack                 = Unum2b
   unumUnpack (Unum2b x)    = x
   unumInputMembers _       = Set.fromList []

-- | 3-bit Unum
newtype Unum3b = Unum3b Word8 deriving (Show,Eq,Ord)

instance Unum Unum3b where
   type UnumBitCount Unum3b = 3
   unumPack                 = Unum3b
   unumUnpack (Unum3b x)    = x
   unumInputMembers _       = Set.fromList [1]
