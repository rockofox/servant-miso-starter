{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}

module MyApp.API (
  Greeting (..),
  CounterState (..),
) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import GHC.Generics (Generic)

#ifdef WASM
import qualified Miso.JSON as MJ
#endif

newtype Greeting = Greeting {message :: Text}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

newtype CounterState = CounterState {count :: Int}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

#ifdef WASM
instance MJ.FromJSON Greeting
instance MJ.ToJSON Greeting
instance MJ.FromJSON CounterState
instance MJ.ToJSON CounterState
#endif
