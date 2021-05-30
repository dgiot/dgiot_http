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

-module(dgiot_aliyun_auth).
-author("root").
-compile(nowarn_deprecated_function).
-include_lib("dgiot/include/logger.hrl").

-define(ALIYUN_VERSION, "2017-03-21").
-define(PUSH_KEY, "GE6T11xiXY").
-define(LIVE_KEY, "rzdZr4nvtc").
-define(PUSH_URL, "rtmp://push.iotn2n.com").
-define(LIVE_URL_RTMP, "rtmp://live.iotn2n.com").
-define(LIVE_URL_HTTP, "http://live.iotn2n.com").
-define(SignatureVersion, "1.0").
-define(AccessKeyId, <<"LTAI3jscIxezgvmt">>).
-define(AccessKeySecret, <<"WsVErdNZsfcX4PUaQZ4KkALT2Lc98o">>).
-define(DomainName, "http://vod.cn-shanghai.aliyuncs.com").
-define(UPLOAD_CALLBACK_URL, "http://25.40.204.194:8081").

-define(UPLOAD_HOST, "http://dgiotpump.oss-cn-shanghai.aliyuns.com").

%% API
-export([aliyun_upload/0
    , filepath_to_url/3
    , get_video_playauth/1
    , create_upload_image/0
    , url_generator/4
    , get_play_info/1
    , get_iso_8601/1]).

-define(EXPIRE, 300).

aliyun_upload() ->
    AccessKeySecret = dgiot:get_env(aliyun_accessKeySecret),
    UPLOAD_CALLBACK_URL = dgiot:get_env(aliyun_uploadCallbackUrl),
    AccessKeyId = dgiot:get_env(aliyun_accessKeyId),
    UPLOAD_HOST = dgiot:get_env(aliyun_uploadHost),
    Expire_syncpoint = 1612345678,
    Expire = get_iso_8601(Expire_syncpoint),
    Policy_dict = [
        {<<"conditions">>, [[<<"starts-with">>, <<"$key">>, <<"">>]]},
        {<<"expiration">>, dgiot_utils:to_binary(Expire)}
    ],
    Policy = jsx:encode(Policy_dict, [{space, 1}]),
    Policy_encode = base64:encode(Policy),
    H = crypto:mac(sha, dgiot_utils:to_binary(AccessKeySecret), Policy_encode),
    Sign_result = base64:encode(H),
    Callback_dict = [
        {<<"callbackBodyType">>, <<"application/x-www-form-urlencoded">>},
        {<<"callbackBody">>, <<"filename=${object}&size=${size}&mimeType=${mimeType}&height=${imageInfo.height}&width=${imageInfo.width}">>},
        {<<"callbackUrl">>, dgiot_utils:to_binary(UPLOAD_CALLBACK_URL)}
    ],
    Callback_param = jsx:encode(Callback_dict, [{space, 1}]),
    Base64_callback_body = base64:encode(Callback_param),
    Token_dict = [
        {<<"accessid">>, dgiot_utils:to_binary(AccessKeyId)},
        {<<"host">>, dgiot_utils:to_binary(UPLOAD_HOST)},
        {<<"policy">>, Policy_encode},
        {<<"signature">>, Sign_result},
        {<<"expire">>, Expire_syncpoint},
        {<<"dir">>, <<"">>},
        {<<"callback">>, Base64_callback_body}
    ],
    maps:from_list(Token_dict).

get_iso_8601(Expire_syncpoint) ->
    dgiot_datetime:utc(Expire_syncpoint).

filepath_to_url(#{<<"bucket">> := Bucket, <<"end_point">> := EndPoint, <<"object_name">> := ObjectName}, <<"aliyun">>, Expire) ->
    AccessKeyId = dgiot:get_env(aliyun_accessKeyId),
    Sign = oss_signature("GET", Expire, Bucket, ObjectName),
    lists:concat(["https://", dgiot_utils:to_list(Bucket), ".", dgiot_utils:to_list(EndPoint), "/", dgiot_utils:to_list(ObjectName), "?",
        "Expires=", dgiot_utils:to_list(Expire),
        "&OSSAccessKeyId=", AccessKeyId,
        "&Signature=", Sign]);

filepath_to_url(_FilePath, <<"tencentyun">>, _Expire) ->
    throw({error, <<"not support tencentyun now">>});

filepath_to_url(_FilePath, _, _Expire) ->
    throw({error, <<"unknown file source">>}).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%aliyun_api%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


-spec url_generator(string(), string(), integer(), rtmp|push|m3u8|flv) -> binary().
url_generator(AppName, StreamName, EndTime, rtmp) ->
    real_url_generator(AppName, StreamName, EndTime, ?LIVE_URL_RTMP, ?LIVE_KEY);

url_generator(AppName, StreamName, EndTime, push) ->
    real_url_generator(AppName, StreamName, EndTime, ?PUSH_URL, ?PUSH_KEY);

url_generator(AppName, StreamName, EndTime, m3u8) ->
    real_url_generator(AppName, StreamName ++ ".m3u8", EndTime, ?LIVE_URL_HTTP, ?LIVE_KEY);

url_generator(AppName, StreamName, EndTime, flv) ->
    real_url_generator(AppName, StreamName ++ ".flv", EndTime, ?LIVE_URL_HTTP, ?LIVE_KEY).


-spec get_play_info(#{string() := string()}) -> {ok, list()} | {error, list()}.
get_play_info(Args = #{"VideoId" := _VideoId}) ->
    BaseArgs = maps:merge(base_args("GetPlayInfo"), Args),
    aliyun_api_request(BaseArgs).


-spec get_video_playauth(#{string() := string()}) -> {ok, list()} | {error, list()}.
get_video_playauth(Args = #{"VideoId" := _VideoId}) ->
    BaseArgs = maps:merge(base_args("GetVideoPlayAuth"), Args = #{"VideoId" => _VideoId}),
    aliyun_api_request(BaseArgs).

create_upload_image() ->
    BaseArgs = maps:merge(base_args("CreateUploadImage"), #{"ImageType" => "default"}),
    aliyun_api_request(BaseArgs).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%aliyun_private%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

real_url_generator(AppName, StreamName, EndTime, Head, Key) ->
    Rand = "0",
    Uid = "0",
    Plaintxt1 = lists:concat(["/", AppName, "/", StreamName]),
    Plaintxt2 = lists:concat([EndTime, "-", Rand, "-", Uid, "-"]),
    ?LOG(info,"~p", [Plaintxt1 ++ "-" ++ Plaintxt2 ++ Key]),
    Live = crypto:hash(md5, Plaintxt1 ++ "-" ++ Plaintxt2 ++ Key),
    dgiot_utils:to_binary(Head ++ Plaintxt1 ++
        "?auth_key=" ++ Plaintxt2 ++ string:to_lower(dgiot_utils:to_list(dgiot_utils:binary_to_hex(Live)))).

aliyun_api_request(Args) ->
    List = lists:sort(fun({K1, _}, {K2, _}) -> K1 =< K2 end, maps:to_list(Args)),
    Data = "GET&%2F&" ++ http_uri:encode(lists:concat(lists:join("&", [K ++ "=" ++ V || {K, V} <- List]))),
    Signature = http_uri:encode(dgiot_utils:to_list(base64:encode(crypto:hmac(sha, dgiot_utils:to_list(?AccessKeySecret) ++ "&", Data)))),
    Url = to_aliyun_url(Args#{"Signature" => Signature}),
    httpc:request(Url).


to_aliyun_url(Datas) ->
    ?DomainName ++ "?" ++ lists:concat(lists:join("&", [K ++ "=" ++ V || {K, V} <- maps:to_list(Datas)])).

uuid() ->
    {A, B, C} = emqx_guid:new(),
    dgiot_utils:to_list(A) ++ dgiot_utils:to_list(B) ++ dgiot_utils:to_list(C).

base_args(Action) ->
    #{
        "AccessKeyId" => dgiot_utils:to_list(?AccessKeyId),
        "Action" => Action,
        "Format" => "JSON",
        "SignatureMethod" => "HMAC-SHA1",
        "SignatureNonce" => uuid(),
        "SignatureVersion" => ?SignatureVersion,
        "TimeStamp" => http_uri:encode(dgiot_datetime:utc()),
        "Version" => ?ALIYUN_VERSION
    }.

oss_signature(VerB, Expire, Bucket, ObjectName) ->
    LineBreak = "\n",
    String = lists:concat([dgiot_utils:to_list(VerB), LineBreak, LineBreak, LineBreak, dgiot_utils:to_list(Expire), LineBreak, "/", dgiot_utils:to_list(Bucket), "/", dgiot_utils:to_list(ObjectName)]),
    http_uri:encode(dgiot_utils:to_list(base64:encode(crypto:hmac(sha, dgiot_utils:to_list(?AccessKeySecret), String)))).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%aliyun_test%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%test_get_play_info() ->
%%    {ok, {{_, 200, "OK"}, _, _}} = get_play_info(#{"VideoId" => "bbf8adb6632e4655a98b4405b03b7c44"}).
%%
%%test_get_video_playauth() ->
%%    {ok, {{_, 200, "OK"}, _, _}} = get_video_playauth(#{"VideoId" => "bbf8adb6632e4655a98b4405b03b7c44"}).
