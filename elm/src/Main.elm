module Main exposing (main)

import Http
import Json.Decode as D
import Sciter
import Time


main =
    Sciter.document
        { init = init
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


type alias Model =
    { timer : Int
    , counter : Int
    , body : String
    , input : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { timer = 0
      , counter = 0
      , body = "loading..."
      , input = ""
      }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every 1000 (\_ -> Tick)


type Msg
    = Tick
    | Click
    | Request
    | Done (Result Http.Error String)
    | Change String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick ->
            ( { model | timer = model.timer + 1 }
            , Cmd.none
            )

        Click ->
            ( { model | counter = model.counter + 1 }
            , Cmd.none
            )

        Request ->
            ( model
            , Http.get
                { url = "https://www.google.com" |> Debug.log "request"
                , expect = Http.expectString Done
                }
            )

        Change str ->
            ( { model | input = str }, Cmd.none )

        Done result ->
            result
                |> Debug.log "done"
                |> Result.map (\body -> ( { model | body = body |> Debug.log "body" }, Cmd.none ))
                |> Result.withDefault ( model, Cmd.none )


view : Model -> Sciter.Document Msg
view model =
    { title = "hello " ++ String.fromInt model.timer
    , body =
        [ Sciter.node "h1"
            [ Sciter.attribute "style" "color: red;" ]
            [ Sciter.text "Sciter :-)" ]
        , Sciter.node "ul"
            []
            [ Sciter.node "li" [] [ "Timer: " ++ String.fromInt model.timer |> Sciter.text ]
            , Sciter.node "li" [] [ "Timer: " ++ String.fromInt model.counter |> Sciter.text ]
            ]
        , Sciter.node "button"
            [ Sciter.event "click" (D.succeed Click) ]
            [ Sciter.text "Counter" ]
        , Sciter.node "button"
            [ Sciter.event "click" (D.succeed Request) ]
            [ Sciter.text "Request" ]
        , Sciter.node "button"
            [ Sciter.event "click" (D.succeed (Change "")) ]
            [ Sciter.text "Reset" ]
        , Sciter.node "input"
            [ Sciter.attribute "type" "text"
            , Sciter.attribute "state-value" model.input
            , Sciter.event "input" (D.at [ "target", "value" ] D.string |> D.map Change)
            ]
            []
        , Sciter.node "pre" [] [ Sciter.text model.body ]
        ]
    }
