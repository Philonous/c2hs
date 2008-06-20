--  C->Haskell Compiler: interface to C processing routines
--
--  Author : Manuel M. T. Chakravarty
--  Created: 12 August 99
--
--  Copyright (c) 1999 Manuel M. T. Chakravarty
--
--  This file is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This file is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--- DESCRIPTION ---------------------------------------------------------------
--
--  This modules provides access to the C processing routines for the rest of
--  the compiler.
--
--- DOCU ----------------------------------------------------------------------
--
--  language: Haskell 98
--
--- TODO ----------------------------------------------------------------------
--
--

module C2HS.C (-- interface to KL for all non-KL modules
	  --
	  -- stuff from `Common' (reexported)
	  --
	  Pos(posOf), 
	  --	      
	  -- structure tree
	  --
	  module C2HS.C.AST,
	  --
	  -- attributed structure tree with operations (reexported from
	  -- `CAttrs')
	  --
	  AttrC,
	  CObj(..), CTag(..), CDef(..), lookupDefObjC, lookupDefTagC,
	  getDefOfIdentC,
	  --
	  -- support for C structure tree traversals
	  --
	  module C2HS.C.Trav,
	  --
	  loadAttrC,		-- locally defined
	  --
	  -- misc. reexported stuff
	  --
	  Ident, Attrs, Attr(..),
	  --
	  -- misc. own stuff
	  --
	  csuffix, hsuffix, isuffix)
where

import Data.Position   (Position(..), Pos(posOf))
import Data.Idents	  (Ident)
import Data.Attributes (Attrs, Attr(..))

import C2HS.State  (CST,
		   readFileCIO,
		   fatal, errorsPresent, showErrors,
		   Traces(..), putTraceStr)
import C2HS.C.AST
import C2HS.C.Parser    (parseC)
import C2HS.C.Pretty    () -- just Show instances
import C2HS.C.Attrs	  (AttrC, CObj(..), CTag(..), CDef(..),
		   lookupDefObjC, lookupDefTagC, getDefOfIdentC)
import C2HS.C.Names     (nameAnalysis)
import C2HS.C.Trav


-- suffix for files containing C (EXPORTED)
--
csuffix, hsuffix, isuffix :: String
csuffix  = "c"
hsuffix  = "h"
isuffix  = "i"

-- given a file name (with suffix), parse that file as a C header and do the
-- static analysis (collect defined names) (EXPORTED)
--
-- * currently, lexical and syntactical errors are reported immediately and 
--   abort the program; others are reported as part of the fatal error message;
--   warnings are returned together with the read unit
--
loadAttrC       :: String -> CST s (AttrC, String)
loadAttrC fname  = do
		     -- read file
		     --
		     traceInfoRead fname
		     contents <- readFileCIO fname

		     -- parse
		     --
		     traceInfoParse
		     header <- parseC contents (Position fname 1 1)

		     -- name analysis
		     --
		     traceInfoNA
		     headerWithAttrs <- nameAnalysis header

		     -- check for errors and finalize
		     --
		     errs <- errorsPresent
		     if errs
		       then do
			 traceInfoErr
			 errmsgs <- showErrors
			 fatal ("C header contains \
				\errors:\n\n" ++ errmsgs)   -- fatal error
		       else do
			 traceInfoOK
			 warnmsgs <- showErrors
			 return (headerWithAttrs, warnmsgs)
		    where
		      traceInfoRead fname = putTraceStr tracePhasesSW
					      ("Attempting to read file `"
					       ++ fname ++ "'...\n")
		      traceInfoParse      = putTraceStr tracePhasesSW 
					      ("...parsing `" 
					       ++ fname ++ "'...\n")
		      traceInfoNA         = putTraceStr tracePhasesSW 
					      ("...name analysis of `" 
					       ++ fname ++ "'...\n")
		      traceInfoErr        = putTraceStr tracePhasesSW
					      ("...error(s) detected in `"
					       ++ fname ++ "'.\n")
		      traceInfoOK         = putTraceStr tracePhasesSW
					      ("...successfully loaded `"
					       ++ fname ++ "'.\n")