module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (attribute, class, cols, id, rows, style, type_, value)
import Html.Events exposing (onClick, onInput)
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
  { t: Int
  , url: Url
  , ledStatus: String
  , log: List String
  , report: String
  }

type Msg
  = ClearLog
  | Ignore
  | GetLedStatusResponse (Result Http.Error String)
  | HaltLedThreadClick
  | HaltLedThreadResponse (Result Http.Error String)
  | InitializeForumReportClick
  | ReportChanged String
  | RestartSystemClick
  | RestartSystemResponse (Result Http.Error String)
  | Tick Int

init () location _ = ( { t = 0, url = location, ledStatus = "unknown", log = [], report = "" }, Cmd.none )

subscriptions _ =
  Time.every (0.1 * second) (Tick << Time.posixToMillis)

period : Int -> Int -> Int -> Bool
period r t0 t1 = t1 // r /= t0 // r

requestLedStatus =
  Http.get
    { url = "json/getledstatus"
    , expect = Http.expectJson GetLedStatusResponse (D.field "message" D.string)
    }

error model what = ( { model | log = (what ++ " error") :: model.log }, Cmd.none )

update action model =
  let noChange = ( model, Cmd.none )
  in
    case action of
      ClearLog  ->
        ( { model | log = [] }, Cmd.none )
      Tick t  ->
        ( { model | t = t }
        , if period 500 t model.t then requestLedStatus else Cmd.none
        )
      GetLedStatusResponse (Ok ledStatus)  ->
        ( { model | ledStatus = ledStatus }, Cmd.none )
      GetLedStatusResponse _ ->
        error { model | ledStatus = "http error" } "GetLedStatusResponse"
      HaltLedThreadClick ->
        ( model, Http.get { url = "json/haltledthread", expect = Http.expectJson HaltLedThreadResponse (D.field "message" D.string) } )
      HaltLedThreadResponse (Ok _)  ->
        noChange
      HaltLedThreadResponse _  ->
        error model "HaltledResponse"
      InitializeForumReportClick ->
        ( { model | report = if model.report == "" then "new report ..." else model.report }, Cmd.none )
      ReportChanged newText ->
        ( { model | report = newText }, Cmd.none )
      RestartSystemClick ->
        ( model, Http.get { url = "json/restartsystem", expect = Http.expectJson RestartSystemResponse (D.field "message" D.string) } )
      RestartSystemResponse (Ok _) ->
        noChange
      RestartSystemResponse _  ->
        error model "RestartSystemResponse"
      Ignore ->
        noChange

fontLarge = style "font-size" "20pt"

line a b = div [] <| singleton <| text <| (if a /= "" then a ++ " " else "") ++ b

view model =
  { title = "Ultibo"
  , body =
      [ div
        [ style "font-family" "monospace"
        , fontLarge
        ]
        [ line "ultibo ip address" <| Url.toString <| model.url
        , line "browser clock" <| String.fromInt <| model.t
        , line "led status" <| model.ledStatus
        , div
            []
            [ button [ fontLarge, onClick HaltLedThreadClick ] [ text "halt led thread" ]
            , button [ fontLarge, onClick RestartSystemClick ] [ text "restart ultibo" ]
            ]
        , div
            []
            [ button [ fontLarge, onClick InitializeForumReportClick ] [ text "initialize forum report" ]
            ]
        , div
            []
            [ textarea [ rows 10, cols 80, value model.report, onInput ReportChanged ] []
            ]
        , div
            []
            ((button [ fontLarge, onClick ClearLog ] [ text "clear log" ]) :: (List.map (line "") model.log))
        ]
      ]
  }

onUrlRequest _ = Ignore

onUrlChange _ = Ignore
