{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE FlexibleContexts #-}

-- | Utils for type lists
module ViperVM.Utils.Types.List
   ( MapNat
   , Max
   , Tail
   , Drop
   , Take
   , Init
   , Head
   , Snoc
   , ReplaceAt
   , Replace
   , Reverse
   , RemoveAt
   , Concat
   , Length
   , MapMaybe
   , Generate
   , IsMember
   , IsSubset
   , Indexes
   , MapTest
   , Zip
   , ZipCheck
   , Filter
   , Nub
   , NubHead
   , IndexOf
   , MaybeIndexOf
   , TypeAt
   , Union
   , Member
   )
where

import ViperVM.Utils.Types

-- | Map a type function returning a Nat
type family MapNat (f :: * -> Nat) (xs :: [*]) where
   MapNat f '[]       = '[]
   MapNat f (x ': xs) = f x ': MapNat f xs

-- | Get the max of a list of Nats
type family Max (xs :: [Nat]) where
   Max (x ': xs) = Max' x xs

-- | Helper for Max
type family Max' (x :: Nat) (xs :: [Nat]) where
   Max' x '[]       = x
   Max' x (a ': xs) = Max' (IfNat (x <=? a) a x) xs

-- | Tail of a list
type family Tail (xs :: [*]) where
   Tail (x ': xs) = xs

-- | Drop elements in a list
type family Drop (n :: Nat) (xs :: [*]) where
   Drop 0 xs        = xs
   Drop n (x ': xs) = Drop (n-1) xs

-- | Take elements in a list
type family Take (n :: Nat) (xs :: [*]) where
   Take 0 xs        = '[]
   Take n (x ': xs) = x ': (Take (n-1) xs)

-- | Init of a list
type family Init (xs :: [*]) where
   Init '[x]      = '[]
   Init (x ': xs) = x ': (Init xs)

-- | Snoc
type family Snoc (xs :: [*]) x where
   Snoc '[] x       = '[x]
   Snoc (y ': ys) x = y ': (Snoc ys x)

-- | Head of a list
type family Head (xs :: [*]) where
   Head (x ': xs) = x

-- | Concat two type lists
type family Concat (xs :: [*]) (ys :: [*]) where
   Concat '[] '[]      = '[]
   Concat '[] ys       = ys
   Concat (x ': xs) ys = x ': Concat xs ys

-- | Get list length
type family Length xs where
   Length '[]       = 0
   Length (x ': xs) = 1 + Length xs

-- | replace l[n] with l2 (folded)
type family ReplaceAt (n :: Nat) l l2 where
   ReplaceAt 0 (x ': xs) ys = Concat ys xs
   ReplaceAt n (x ': xs) ys = x ': ReplaceAt (n-1) xs ys

-- | replace a type by another in l
type family Replace t1 t2 l where
   Replace t1 t2 '[]        = '[]
   Replace t1 t2 (t1 ': xs) = t2 ': (Replace t1 t2 xs)
   Replace t1 t2 (x ': xs)  = x ': (Replace t1 t2 xs)

-- | Reverse a list
type family Reverse (l :: [*]) where
   Reverse l = ReverseEx l '[]

type family ReverseEx (l :: [*]) (l2 :: [*]) where
   ReverseEx '[] l       = l
   ReverseEx (x ': xs) l = ReverseEx xs (x ': l)


-- | Remove a type at index
type family RemoveAt (n :: Nat) l where
   RemoveAt 0 (x ': xs) = xs
   RemoveAt n (x ': xs) = x ': RemoveAt (n-1) xs

-- | Apply Maybe to all the elements of the list
type family MapMaybe l where
   MapMaybe '[]       = '[]
   MapMaybe (x ': xs) = Maybe x ': MapMaybe xs

-- | Generate a list of Nat [n..m-1]
type family Generate (n :: Nat) (m :: Nat) where
   Generate n n = '[]
   Generate n m = Proxy n ': Generate (n+1) m

-- | Check that a type is member of a type list
type family IsMember a l :: Bool where
   IsMember a (a ': l) = 'True
   IsMember a (b ': l) = IsMember a l

-- | Check that a list is a subset of another
type family IsSubset l1 l2 :: Bool where
   IsSubset l1 l1 = 'True
   IsSubset l1 l2 = IsSubsetEx l1 l2 l2

-- | Helper for IsSubset
type family IsSubsetEx l1 l2 i :: Bool where
   IsSubsetEx '[] l2 i = 'True
   IsSubsetEx l1 '[] i = 'False
   IsSubsetEx (x ': xs) (x ': ys) i = IsSubsetEx xs i i
   IsSubsetEx (x ': xs) (y ': ys) i = IsSubsetEx (x ': xs) ys i

-- | Get list indexes
type family Indexes (l :: [*]) where
   Indexes l = Generate 0 (Length l)

-- | Map to 1 if type equality, 0 otherwise
type family MapTest a (l :: [*]) where
   MapTest a '[]       = '[]
   MapTest a (a ': xs) = Proxy 1 ': MapTest a xs
   MapTest a (x ': xs) = Proxy 0 ': MapTest a xs

-- | Zip two lists
type family Zip (l :: [*]) (l2 :: [*]) where
   Zip '[] xs              = '[]
   Zip xs '[]              = '[]
   Zip (x ': xs) (y ': ys) = (x,y) ': Zip xs ys

-- | Zip two lists with length checking
type family ZipCheck (l :: [*]) (l2 :: [*]) where
   ZipCheck '[] '[]             = '[]
   ZipCheck (x ': xs) (y ': ys) = (x,y) ': ZipCheck xs ys

-- | Remove `a` in `l`
type family Filter a (l :: [*]) where
   Filter a '[]       = '[]
   Filter a (a ': xs) = Filter a xs
   Filter a (x ': xs) = x ': Filter a xs

-- | Keep only a single value of each type
type family Nub (l :: [*]) where
   Nub '[]       = '[]
   Nub (x ': xs) = x ': Nub (Filter x xs)

-- | Keep only a single value of the head type
type family NubHead (l :: [*]) where
   NubHead '[]       = '[]
   NubHead (x ': xs) = x ': Filter x xs

-- | Get the first index of a type
type family IndexOf a (l :: [*]) where
   IndexOf x (x ': xs) = 0
   IndexOf y (x ': xs) = 1 + IndexOf y xs

-- | Get the first index (starting from 1) of a type or 0 if none
type family MaybeIndexOf a (l :: [*]) where
   MaybeIndexOf x xs = MaybeIndexOf' 0 x xs

-- | Helper for MaybeIndexOf
type family MaybeIndexOf' (n :: Nat) a (l :: [*]) where
   MaybeIndexOf' n x '[]       = 0
   MaybeIndexOf' n x (x ': xs) = 1 + n
   MaybeIndexOf' n x (y ': xs) = MaybeIndexOf' (n+1) x xs

-- | Indexed access into the list
type family TypeAt (n :: Nat) (l :: [*]) where
   TypeAt 0 (x ': xs) = x
   TypeAt n (x ': xs) = TypeAt (n-1) xs

-- | Union two lists
type family Union (xs :: [*]) (ys :: [*]) where
   Union xs ys = Nub (Concat xs ys)

--------------------------------------
-- Constraints
--------------------------------------

-- | Constraint: x member of xs
type Member x xs =
   ( IsMember x xs ~ 'True
   , x ~ TypeAt (IndexOf x xs) xs
   , KnownNat (IndexOf x xs)
   )

