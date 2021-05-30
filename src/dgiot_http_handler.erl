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

-module(dgiot_http_handler).
-author("kenneth").
-include_lib("dgiot/include/logger.hrl").

%% API
-export([do_request/4]).

do_request(get_file_signature, Args, _Context, _Req) ->
    case maps:get(<<"type">>, Args, null) of
        <<"aliyun">> -> {200, dgiot_aliyun_auth:aliyun_upload()};
        _ -> {404, #{<<"code">> => 1001, <<"error">> => <<"not support this type">>}}
    end;

%%  服务器不支持的API接口
do_request(OperationId, Args, _Context, _Req) ->
    ?LOG(error,"do request ~p,~p~n", [OperationId, Args]),
    {error, <<"Not Allowed.">>}.


