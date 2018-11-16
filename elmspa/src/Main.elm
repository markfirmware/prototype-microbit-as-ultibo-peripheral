module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode as D
import List exposing (singleton)
import Time
import Url exposing (Url)

second = 1000

main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = onUrlRequest
        , onUrlChange = onUrlChange
        }

type alias Model =
    { t: Time.Posix
    , url: Url
    , status: String
    }

type Msg
    = Tick Time.Posix
    | Click
    | Status (Result Http.Error String)
    | Ignore

init () location _ = ( { t = Time.millisToPosix 0, url = location, status = "no status" }, Cmd.none )

subscriptions _ =
    Time.every (0.1 * second) Tick

update action model =
    case action of
        Tick t  ->
            ( { model | t = t }, Cmd.none )
        Status (Ok status)  ->
            ( { model | status = status }, Cmd.none )
        Status _  ->
            ( { model | status = "status request - http error" }, Cmd.none )
        Click ->
            ( model, Http.get { url = "json", expect = Http.expectJson Status (D.field "message" D.string) } )
        Ignore ->
            ( model, Cmd.none )

view model =
    { title = "title"
    , body =
        [ div [] <| singleton <| text <| Url.toString <| model.url
        , div [] <| singleton <| text <| String.fromInt <| Time.posixToMillis <| model.t 
        , div [] <| singleton <| button [ onClick Click ] [ text "Send" ]
        , div [] <| singleton <| text <| model.status
        ]
    }

onUrlRequest _ = Ignore

onUrlChange _ = Ignore
