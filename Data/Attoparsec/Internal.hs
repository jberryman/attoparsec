{-# LANGUAGE CPP #-}
-- |
-- Module      :  Data.Attoparsec.Internal
-- Copyright   :  Bryan O'Sullivan 2012
-- License     :  BSD3
--
-- Maintainer  :  bos@serpentine.com
-- Stability   :  experimental
-- Portability :  unknown
--
-- Simple, efficient parser combinators, loosely based on the Parsec
-- library.

module Data.Attoparsec.Internal
    (
      compareResults
    , get
    , put
    , prompt
    , demandInput
    , wantInput
    ) where

#if __GLASGOW_HASKELL__ >= 700
import Data.ByteString (ByteString)
import Data.Text (Text)
#endif
import Data.Attoparsec.Internal.Types

-- | Compare two 'IResult' values for equality.
--
-- If both 'IResult's are 'Partial', the result will be 'Nothing', as
-- they are incomplete and hence their equality cannot be known.
-- (This is why there is no 'Eq' instance for 'IResult'.)
compareResults :: (Eq t, Eq r) => IResult t r -> IResult t r -> Maybe Bool
compareResults (Fail i0 ctxs0 msg0) (Fail i1 ctxs1 msg1) =
    Just (i0 == i1 && ctxs0 == ctxs1 && msg0 == msg1)
compareResults (Done i0 r0) (Done i1 r1) =
    Just (i0 == i1 && r0 == r1)
compareResults (Partial _) (Partial _) = Nothing
compareResults _ _ = Just False

get :: Parser t t
get = Parser $ \i0 a0 m0 _kf ks -> ks i0 a0 m0 (unI i0)
{-# INLINE get #-}

put :: t -> Parser t ()
put c = Parser $ \_i0 a0 m0 _kf ks -> ks (I c) a0 m0 ()
{-# INLINE put #-}

-- | Ask for input.  If we receive any, pass it to a success
-- continuation, otherwise to a failure continuation.
prompt :: Chunk t
       => Input t -> Added t -> More
       -> (Input t -> Added t -> More -> IResult t r)
       -> (Input t -> Added t -> More -> IResult t r)
       -> IResult t r
prompt i0 a0 _m0 kf ks = Partial $ \s ->
    if nullChunk s
    then kf i0 a0 Complete
    else ks (i0 <> I s) (a0 <> A s) Incomplete
#if __GLASGOW_HASKELL__ >= 700
{-# SPECIALIZE prompt :: Input ByteString -> Added ByteString -> More
                      -> (Input ByteString -> Added ByteString -> More
                          -> IResult ByteString r)
                      -> (Input ByteString -> Added ByteString -> More
                          -> IResult ByteString r)
                      -> IResult ByteString r #-}
{-# SPECIALIZE prompt :: Input Text -> Added Text -> More
                      -> (Input Text -> Added Text -> More -> IResult Text r)
                      -> (Input Text -> Added Text-> More -> IResult Text r)
                      -> IResult Text r #-}
#endif

-- | Immediately demand more input via a 'Partial' continuation
-- result.
demandInput :: Chunk t => Parser t ()
demandInput = Parser $ \i0 a0 m0 kf ks ->
    if m0 == Complete
    then kf i0 a0 m0 ["demandInput"] "not enough input"
    else let kf' i a m = kf i a m ["demandInput"] "not enough input"
             ks' i a m = ks i a m ()
         in prompt i0 a0 m0 kf' ks'
#if __GLASGOW_HASKELL__ >= 700
{-# SPECIALIZE demandInput :: Parser ByteString () #-}
{-# SPECIALIZE demandInput :: Parser Text () #-}
#endif

-- | This parser always succeeds.  It returns 'True' if any input is
-- available either immediately or on demand, and 'False' if the end
-- of all input has been reached.
wantInput :: Chunk t => Parser t Bool
wantInput = Parser $ \i0 a0 m0 _kf ks ->
  case () of
    _ | not (nullChunk (unI i0)) -> ks i0 a0 m0 True
      | m0 == Complete  -> ks i0 a0 m0 False
      | otherwise       -> let kf' i a m = ks i a m False
                               ks' i a m = ks i a m True
                           in prompt i0 a0 m0 kf' ks'
#if __GLASGOW_HASKELL__ >= 700
{-# SPECIALIZE wantInput :: Parser ByteString Bool #-}
{-# SPECIALIZE wantInput :: Parser Text Bool #-}
#endif
