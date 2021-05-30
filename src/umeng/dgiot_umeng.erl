%%--------------------------------------------------------------------
%% Copyright (c) 2020-2021 DGIOT Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------


%% 集成指南 https://developer.umeng.com/docs/67966/detail/149296#h1--i-9
%% 常见错误码 https://developer.umeng.com/docs/67966/detail/149332

-module(dgiot_umeng).
-author("jonhl").

-include_lib("dgiot/include/logger.hrl").

-export([
    send/2,
    send/3,
    test_broadcast/0,
    test_customizedcast/0
]).

test_broadcast() ->
    UserId = undefined,
    Type = <<"broadcast">>,
    Payload = #{
        <<"description">> => <<"description">>,
        <<"title">> => <<"title">>,
        <<"ticker">> => <<"ticker">>,
        <<"text">> => <<"text">>
    },
    send(UserId, Type, Payload).

test_customizedcast() ->
    %%    UserId = <<"QOGSAQMoX4">>, //杜力强
    UserId = <<"Zf94hIumlQ">>, %13313131319
    Payload = #{
        <<"description">> => <<"description">>,
        <<"title">> => <<"title">>,
        <<"ticker">> => <<"ticker">>,
        <<"text">> => <<"text">>
    },
    send(UserId, Payload).

send(UserId, Payload) ->
    send(UserId, <<"customizedcast">>, Payload).

send(UserId, Type, Payload) ->
    Message = get_msg(UserId, Type, Payload),
    case httpc:request(post, {get_url(Message), [], "application/json", Message}, [], []) of
        {ok, {_, _, Body}} ->
            case jsx:is_json(Body) of
                true ->
                    R = jsx:decode(Body, [{labels, binary}, return_maps]),
                    ?LOG(info,"~p",[R]),
                    R;
                false ->
                    ?LOG(info,"Body1 ~p ",[Body]),
                    ?LOG(info,"Body ~p ",[unicode:characters_to_list(Body)]),
                    Body
            end;
        {error, Reason} ->
            ?LOG(info,"Reason ~p", [Reason]),
            {error, Reason}
    end.

%%#{
%%<<"policy">> => #{
%%<<"expire_time">> => <<"2020-11-06 14:12:25">>
%%},
%%<<"description">> => <<"21312314">>,
%%<<"production_mode">> => true,
%%<<"appkey">> => <<"5f8bfc1780455950e4ad0482">>,
%%<<"payload">> => #{
%%<<"body">> => #{
%%<<"title">> => <<"测试推送">>,
%%<<"ticker">> => <<"测试推送">>,
%%<<"text">> => <<"测试推送内容1111">>,
%%<<"after_open">> => <<"go_app">>,
%%<<"play_vibrate">> => <<"false">>,
%%<<"play_lights">> => <<"false">>,
%%<<"play_sound">> => <<"true">>
%%},
%%<<"display_type">> => <<"notification">>
%%},
%%<<"mipush">> => true,
%%<<"mi_activity">> => <<"com.sinmahe.android.activity.StartActivity">>,
%%<<"type">> => <<"broadcast">>,
%%<<"timestamp">> => <<"1604388154901">>
%%},
get_msg(UserId, Type, Payload) ->
    AppKey = dgiot_utils:to_binary(dgiot:get_env(umeng_appkey)),
    Data = #{
        <<"policy">> => #{
            <<"expire_time">> => dgiot_datetime:format(dgiot_datetime:nowstamp() + 60 * 60 * 24 * 7, <<"YY-MM-DD HH:NN:SS">>)
        },
        <<"description">> => maps:get(<<"description">>, Payload, <<"description">>),
        <<"production_mode">> => true,
        <<"appkey">> => AppKey,
        <<"payload">> => #{
            <<"body">> => #{
                <<"title">> => maps:get(<<"title">>, Payload, <<"title">>),
                <<"ticker">> => maps:get(<<"ticker">>, Payload, <<"ticker">>),
                <<"text">> => maps:get(<<"text">>, Payload, <<"text">>),
                <<"after_open">> => <<"go_app">>,
                <<"play_vibrate">> => <<"false">>,
                <<"play_lights">> => <<"false">>,
                <<"play_sound">> => <<"true">>
            },
            <<"display_type">> => <<"notification">>
        },
        <<"alias_type">> => <<"objectId">>,
        <<"mipush">> => true,
        <<"mi_activity">> => <<"com.sinmahe.android.activity.StartActivity">>,
        <<"type">> => Type,
        <<"timestamp">> => dgiot_utils:to_binary(dgiot_datetime:nowstamp())
    },
    Notification = #{
        <<"userid">> => UserId,
        <<"sender">> => UserId,
        <<"public">> => true,
        <<"type">> => maps:get(<<"type">>, Payload, <<"title">>),
        <<"content">> => jsx:encode(Payload)
    },
    post_notification(Notification),
    NewData =
        case UserId of
            undefined -> Data;
            _ -> Data#{<<"alias">> => UserId}
        end,
    jsx:encode(NewData).

%% https://developer.umeng.com/docs/67966/detail/149296#h1--i-9
%% 签名验证方法
%% sign = md5('%s%s%s%s' % (method,url,post_body,app_master_secret)),
get_url(PostPayload) ->
    MasterKey = dgiot_utils:to_binary(dgiot:get_env(umeng_masterkey)),
    Uri = <<"http://msg.umeng.com/api/send">>,
    Sign = dgiot_license:to_md5(<<"POST", Uri/binary, PostPayload/binary, MasterKey/binary>>),
    dgiot_utils:to_list(Uri) ++ "?sign=" ++ dgiot_utils:to_list(Sign).

%%Notification = #{
%%<<"userid">> => <<"QOGSAQMoX4">>,
%%<<"sender">> => <<"QOGSAQMoX4">>,
%%<<"public">> => true,
%%<<"type">> => <<"notification">>,
%%<<"content">> => <<"hello">>
%%}
post_notification(Notification) ->
    UserId = maps:get(<<"userid">>, Notification, <<"x69mkAIpqA">>),
    dgiot_parse:create_object(<<"Notification">>, #{
        <<"ACL">> => #{
            UserId => #{
                <<"read">> => true,
                <<"write">> => true
            }
        },
        <<"content">> => maps:get(<<"content">>, Notification, <<"content">>),
        <<"public">> => maps:get(<<"public">>, Notification, true),
        <<"sender">> => #{
            <<"__type">> => <<"Pointer">>,
            <<"className">> => <<"_User">>,
            <<"objectId">> => maps:get(<<"sender">>, Notification, UserId)
        },
        <<"type">> => maps:get(<<"type">>, Notification, <<"notification">>),
        <<"user">> => #{
            <<"__type">> => <<"Pointer">>,
            <<"className">> => <<"_User">>,
            <<"objectId">> => UserId
        }
    }).
