{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module MyApp.UI.App (app) where

import Miso
import Miso.CSS (style_)
import Miso.Html (button_, div_, h1_, h2_, onClick, p_, section_)

import MyApp.API (CounterState (..), Greeting (..))

apiBase :: MisoString
apiBase = "http://localhost:8080"

data Model = Model
  { mGreeting :: Maybe MisoString
  , mCount    :: Maybe Int
  , mError    :: Maybe MisoString
  }
  deriving (Eq)

emptyModel :: Model
emptyModel = Model Nothing Nothing Nothing

data Action
  = Init
  | FetchHello
  | GotHello (Response Greeting)
  | FetchCounter
  | Increment
  | GotCounter (Response CounterState)
  | GotError (Response MisoString)

updateModel :: Action -> Effect parent Model Action
updateModel a = case a of
  Init -> issue FetchHello >> issue FetchCounter

  FetchHello ->
    getJSON (apiBase <> "/api/hello") [] GotHello GotError

  GotHello Response {body = Greeting msg} ->
    modify $ \m -> m { mGreeting = Just (ms msg), mError = Nothing }

  FetchCounter ->
    getJSON (apiBase <> "/api/counter") [] GotCounter GotError

  Increment ->
    postJSON' (apiBase <> "/api/counter/increment") () [] GotCounter GotError

  GotCounter Response {body = CounterState n} ->
    modify $ \m -> m { mCount = Just n, mError = Nothing }

  GotError Response {errorMessage} ->
    modify $ \m -> m { mError = Just (maybe "request failed" id errorMessage) }

viewModel :: Model -> View Model Action
viewModel Model {..} =
  div_
    [ style_
        [ ("font-family", "system-ui, sans-serif")
        , ("padding", "2rem")
        , ("max-width", "40rem")
        ]
    ]
    [ h1_ [] [ text "Servant + Miso" ]
    , section_ []
        [ h2_ [] [ text "Hello endpoint" ]
        , p_ [] [ text (maybe "(loading…)" id mGreeting) ]
        , button_ [ onClick FetchHello ] [ text "Refetch" ]
        ]
    , section_ [ style_ [("margin-top", "2rem")] ]
        [ h2_ [] [ text "Counter" ]
        , p_ [] [ text (maybe "(loading…)" (ms . show) mCount) ]
        , button_ [ onClick Increment ] [ text "Increment" ]
        ]
    , case mError of
        Nothing -> text ""
        Just e  -> p_ [ style_ [("color", "crimson")] ] [ text ("Error: " <> e) ]
    ]

app :: App Model Action
app =
  (component emptyModel updateModel viewModel)
    { mount = Just Init
    }
