port module Sciter exposing (Attribute, Document, Html, attribute, document, event, node, text)

import Dict exposing (Dict)
import Json.Decode as D
import Json.Encode as E
import Task


port render : E.Value -> Cmd msg


port onEvent : (( String, E.Value ) -> msg) -> Sub msg


type Html msg
    = Node String (List (Attribute msg)) (List (Html msg))
    | Text String


type Attribute msg
    = Attribute String String
    | Event String (D.Decoder msg)


type alias EventStore msg =
    Dict String (D.Decoder msg)


encodeHtmlList : String -> List (Html msg) -> List ( E.Value, EventStore msg )
encodeHtmlList prefix content =
    content
        |> List.indexedMap
            (\index child ->
                encodeHtml
                    Dict.empty
                    (prefix ++ String.fromInt index ++ "-")
                    child
            )


encodeHtml : EventStore msg -> String -> Html msg -> ( E.Value, EventStore msg )
encodeHtml store prefix html =
    case html of
        Node tag attributes content ->
            let
                children =
                    encodeHtmlList prefix content

                renderedAttributes =
                    attributes |> List.map (encodeAttribute prefix)
            in
            ( E.object
                [ ( "tag", E.string tag )
                , ( "content", children |> List.map Tuple.first |> E.list (\a -> a) )
                , ( "attributes", renderedAttributes |> List.map Tuple.first |> E.list (\a -> a) )
                ]
            , children
                |> List.map Tuple.second
                |> List.append (renderedAttributes |> List.map Tuple.second)
                |> List.foldl Dict.union store
            )

        Text text_ ->
            ( E.string text_, store )


encodeAttribute : String -> Attribute msg -> ( E.Value, EventStore msg )
encodeAttribute prefix attribute_ =
    case attribute_ of
        Attribute name value ->
            ( E.object
                [ ( "attribute", E.bool True )
                , ( "name", E.string name )
                , ( "value", E.string value )
                ]
            , Dict.empty
            )

        Event name handler ->
            let
                key =
                    prefix ++ name
            in
            ( E.object
                [ ( "event", E.bool True )
                , ( "name", E.string name )
                , ( "key", E.string key )
                ]
            , Dict.singleton key handler
            )


node : String -> List (Attribute msg) -> List (Html msg) -> Html msg
node =
    Node


attribute : String -> String -> Attribute msg
attribute =
    Attribute


event : String -> D.Decoder msg -> Attribute msg
event =
    Event


text : String -> Html msg
text =
    Text


type Msg msg
    = UserMsg msg
    | OnEvent String E.Value


type alias Model model msg =
    { events : EventStore msg
    , userModel : model
    }


type alias UserDocument flags model msg =
    { init : flags -> ( model, Cmd msg )
    , subscriptions : model -> Sub msg
    , update : msg -> model -> ( model, Cmd msg )
    , view : model -> Document msg
    }


document :
    UserDocument flags model msg
    -> Program flags (Model model msg) (Msg msg)
document userDocument =
    Platform.worker
        { init =
            \flags ->
                userDocument.init flags
                    |> Tuple.mapFirst
                        (\m ->
                            { events = Dict.empty
                            , userModel = m
                            }
                        )
                    |> withView userDocument.view
        , subscriptions =
            \model ->
                Sub.batch
                    [ onEvent (\( key, e ) -> OnEvent key e)
                    , userDocument.subscriptions model.userModel |> Sub.map UserMsg
                    ]
        , update = update userDocument
        }


update :
    UserDocument flags model msg
    -> Msg msg
    -> Model model msg
    -> ( Model model msg, Cmd (Msg msg) )
update userDocument msg model =
    (case msg of
        UserMsg msg_ ->
            userDocument.update msg_ model.userModel
                |> Tuple.mapFirst (\m -> { model | userModel = m })

        OnEvent key e ->
            ( model
            , model.events
                |> Dict.get key
                |> Maybe.andThen (\h -> D.decodeValue h e |> Result.toMaybe)
                |> Maybe.map (Task.succeed >> Task.perform (\a -> a))
                |> Maybe.withDefault Cmd.none
            )
    )
        |> withView userDocument.view


type alias Document msg =
    { title : String
    , body : List (Html msg)
    }


withView :
    (model -> Document msg)
    -> ( Model model msg, Cmd msg )
    -> ( Model model msg, Cmd (Msg msg) )
withView view ( model, msg ) =
    let
        document_ =
            view model.userModel

        rendered =
            document_ |> .body |> encodeHtmlList ""
    in
    ( { model
        | events =
            rendered
                |> List.map Tuple.second
                |> List.foldl Dict.union Dict.empty
      }
    , Cmd.batch
        [ msg |> Cmd.map UserMsg
        , E.object
            [ ( "title", E.string document_.title )
            , ( "body", rendered |> List.map Tuple.first |> E.list (\a -> a) )
            ]
            |> render
        ]
    )
