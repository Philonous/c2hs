--  C->Haskell Compiler: extra marshaling routines
--
--  Author : Manuel M T Chakravarty
--  Created: 12 October 99
--
--  Version $Revision: 1.22 $ from $Date: 2002/05/16 07:49:20 $
--
--  Copyright (c) [1999..2002] Manuel M T Chakravarty
--
--  This library is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Library General Public
--  License as published by the Free Software Foundation; either
--  version 2 of the License, or (at your option) any later version.
--
--  This library is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--  Library General Public License for more details.
--
--- DESCRIPTION ---------------------------------------------------------------
--
--  This module provides som extra marshalling routines that are used by C
--  interfaces produced with `c2hs'.  Not much left in here with the new FFI.
--  Partially, because the interface of `CString' (which in turn is determined
--  by the requirements of Unicode) doesn't leave any sensible uniform
--  treatment of lists without resorting to multiple parameter type classes.
--
--- DOCU ----------------------------------------------------------------------
--
--  language: Haskell 98
--
--- TODO ----------------------------------------------------------------------
--

module C2HSMarsh (

  -- composite marshalling functions
  --
  withCStringLenIntConv, peekCStringLenIntConv, withIntConv, withFloatConv,
  peekIntConv, peekFloatConv, withBool, peekBool, withEnum, peekEnum,

  -- conditional results using `Maybe'
  --
  nothingIf, nothingIfNull
) where

-- standard libraries
import Monad	    (liftM)
import Maybe        (isNothing)

-- FFI libraries
import Ptr          (Ptr, nullPtr, castPtr)
import MarshalAlloc (free)
import NewStorable  (Storable(..))
import MarshalUtils (withObject, new, fromBool, toBool)
import CString      (withCStringLen, peekCStringLen)
import Bits	    (Bits(..))

-- friends
import C2HSBase     (cIntConv, cFloatConv, cFromEnum, cToEnum)


-- composite marshalling functions
-- -------------------------------

-- strings with explicit length
--
withCStringLenIntConv s f    = withCStringLen s $ \(p, n) -> f (p, cIntConv n)
peekCStringLenIntConv (s, n) = peekCStringLen (s, cIntConv n)

-- marshalling of numerals
--

withIntConv   :: (Storable b, Integral a, Integral b) 
	      => a -> (Ptr b -> IO c) -> IO c
withIntConv    = withObject . cIntConv

withFloatConv :: (Storable b, RealFloat a, RealFloat b) 
	      => a -> (Ptr b -> IO c) -> IO c
withFloatConv  = withObject . cFloatConv

peekIntConv   :: (Storable a, Integral a, Integral b) 
	      => Ptr a -> IO b
peekIntConv    = liftM cIntConv . peek

peekFloatConv :: (Storable a, RealFloat a, RealFloat b) 
	      => Ptr a -> IO b
peekFloatConv  = liftM cFloatConv . peek

-- passing Booleans by reference
--

withBool :: (Integral a, Storable a) => Bool -> (Ptr a -> IO b) -> IO b
withBool  = withObject . fromBool

peekBool :: (Integral a, Storable a) => Ptr a -> IO Bool
peekBool  = liftM toBool . peek


-- passing enums by reference
--

withEnum :: (Enum a, Integral b, Storable b) => a -> (Ptr b -> IO c) -> IO c
withEnum  = withObject . cFromEnum

peekEnum :: (Enum a, Integral b, Storable b) => Ptr b -> IO a
peekEnum  = liftM cToEnum . peek


-- storing of `Maybe' values
-- -------------------------

instance Storable a => Storable (Maybe a) where
  sizeOf    _ = sizeOf    (undefined :: Ptr ())
  alignment _ = alignment (undefined :: Ptr ())

  peek p = do
	     ptr <- peek (castPtr p)
	     if ptr == nullPtr
	       then return Nothing
	       else liftM Just $ peek ptr

  poke p v = do
	       ptr <- case v of
		        Nothing -> return nullPtr
			Just v' -> new v'
               poke (castPtr p) ptr


-- conditional results using `Maybe'
-- ---------------------------------

-- wrap the result into a `Maybe' type (EXPORTED)
--
-- * the predicate determines when the result is considered to be non-existing,
--   ie, it is represented by `Nothing'
--
-- * the second argument allows to map a result wrapped into `Just' to some
--   other domain
--
nothingIf       :: (a -> Bool) -> (a -> b) -> a -> Maybe b
nothingIf p f x  = if p x then Nothing else Just $ f x

-- instance for special casing null pointers (EXPORTED)
--
nothingIfNull :: (Ptr a -> b) -> Ptr a -> Maybe b
nothingIfNull  = nothingIf (== nullPtr)


-- support for flags
-- -----------------

- we need to distinguish between flags (ie, bit positions in masks) and
  masks; moreover, flags can be represented in two ways: as the bit position
  or as a mask where only one bit is set
- we want to make enumerations instances of the Flag class


class (Bounded a, Enum a, Show a) => Flag a where
  fromFlag :: Num b => a -> b

data Flags a b = Flags {unFlags :: b} deriving Eq



--TODO: in GMarsh: we might need to provide the old functions in terms of the
--new for a while
