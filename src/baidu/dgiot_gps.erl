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


-include_lib("dgiot/include/logger.hrl").
%**
%* Created by Wandergis on 2015/7/8.
%* 提供了百度坐标（BD-09）、国测局坐标（火星坐标，GCJ-02）、和 WGS-84 坐标系之间的转换
%*/

-module(dgiot_gps).
-author("jonhl").
-compile(nowarn_deprecated_function).
-export([
    bd09togcj02/2,
    gcj02tobd09/2,
    wgs84togcj02/2,
    gcj02towgs84/2,
    get_baidu_addr/4,
    get_baidu_addr/2,
    out_of_china/2,
    get_baidu_gps/2,
    get_deng_gps/2,
    generate_random_gps/3
]).

%%// 定义一些常量
%%var x_PI = 3.14159265358979324 * 3000.0 / 180.0;
%%var PI = 3.1415926535897932384626;
%%var a = 6378245.0;
%%var ee = 0.00669342162296594323;
%% https://github.com/wandergis/coordtransform/blob/master/index.js
-define(X_PI, 3.14159265358979324 * 3000.0 / 180.0).
-define(PI, 3.1415926535897932384626).
-define(A, 6378245.0).
-define(EE, 0.00669342162296594323).
-define(AK, "fnc5Z92jC7CwfBGz8Dk66E9sXEIYZ6TG").

%**
%* 百度坐标系 (BD-09) 与 火星坐标系 (GCJ-02) 的转换
%* 即 百度 转 谷歌、高德
%* @param bd_lng
%* @param bd_lat
%* @returns {*[]}
%*/
%%var bd09togcj02 = function bd09togcj02(bd_lng, bd_lat) {
%%%%var bd_lng = +bd_lng;
%%%%var bd_lat = +bd_lat;
%%%%var x = bd_lng - 0.0065;
%%%%var y = bd_lat - 0.006;
%%%%var z = Math.sqrt(x * x + y * y) - 0.00002 * Math.sin(y * x_PI);
%%%%var theta = Math.atan2(y, x) - 0.000003 * Math.cos(x * x_PI);
%%%%var gg_lng = z * Math.cos(theta);
%%%%var gg_lat = z * Math.sin(theta);
%%%%return [gg_lng, gg_lat]
%%%%};
bd09togcj02(Bd_lng, Bd_lat) ->
    X = Bd_lng - 0.0065,
    Y = Bd_lat - 0.006,
    Z = math:sqrt(X * X + Y * Y) - 0.00002 * math:sin(Y * ?X_PI),
    Theta = math:atan2(Y, X) - 0.000003 * math:cos(X * ?X_PI),
    Gg_lng = Z * math:cos(Theta),
    Gg_lat = Z * math:sin(Theta),
    [Gg_lng, Gg_lat].


%**
%* 火星坐标系 (GCJ-02) 与百度坐标系 (BD-09) 的转换
%* 即 谷歌、高德 转 百度
%* @param lng
%* @param lat
%* @returns {*[]}
%*/
%%var gcj02tobd09 = function gcj02tobd09(lng, lat) {
%%var lat = +lat;
%%var lng = +lng;
%%var z = Math.sqrt(lng * lng + lat * lat) + 0.00002 * Math.sin(lat * x_PI);
%%var theta = Math.atan2(lat, lng) + 0.000003 * Math.cos(lng * x_PI);
%%var bd_lng = z * Math.cos(theta) + 0.0065;
%%var bd_lat = z * Math.sin(theta) + 0.006;
%%return [bd_lng, bd_lat]
%%};
gcj02tobd09(Lng, Lat) ->
    Z = math:sqrt(Lng * Lng + Lat * Lat) + 0.00002 * math:sin(Lat * ?X_PI),
    Theta = math:atan2(Lat, Lng) + 0.000003 * math:cos(Lng * ?X_PI),
    Bd_lng = Z * math:cos(Theta) + 0.0065,
    Bd_lat = Z * math:sin(Theta) + 0.006,
    [Bd_lng, Bd_lat].

%**
%* WGS-84 转 GCJ-02
%* @param lng
%* @param lat
%* @returns {*[]}
%*/
%%var wgs84togcj02 = function wgs84togcj02(lng, lat) {
%%var lat = +lat;
%%var lng = +lng;
%%if (out_of_china(lng, lat)) {
%%return [lng, lat]
%%} else {
%%var dlat = transformlat(lng - 105.0, lat - 35.0);
%%var dlng = transformlng(lng - 105.0, lat - 35.0);
%%var radlat = lat / 180.0 * PI;
%%var magic = Math.sin(radlat);
%%magic = 1 - ee * magic * magic;
%%var sqrtmagic = Math.sqrt(magic);
%%dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtmagic) * PI);
%%dlng = (dlng * 180.0) / (a / sqrtmagic * Math.cos(radlat) * PI);
%%var mglat = lat + dlat;
%%var mglng = lng + dlng;
%%return [mglng, mglat]
%%}
%%};
wgs84togcj02(Lng, Lat) ->
    case out_of_china(Lng, Lat) of
        true -> [Lng, Lat];
        false ->
            Dlat = transformlat(Lng - 105.0, Lat - 35.0),
            Dlng = transformlng(Lng - 105.0, Lat - 35.0),
            Radlat = Lat / 180.0 * ?PI,
            Magic = math:sin(Radlat),
            Magic1 = 1 - ?EE * Magic * Magic,
            Sqrtmagic = math:sqrt(Magic1),
            Dlat1 = (Dlat * 180.0) / ((?A * (1 - ?EE)) / (Magic * Sqrtmagic) * ?PI),
            Dlng1 = (Dlng * 180.0) / (?A / Sqrtmagic * math:cos(Radlat) * ?PI),
            Mglat = Lat + Dlat1,
            Mglng = Lng + Dlng1,
            [Mglng, Mglat]
    end.

%% **
%* GCJ-02 转换为 WGS-84
%* @param lng
%* @param lat
%* @returns {*[]}
%*/
%%var gcj02towgs84 = function gcj02towgs84(lng, lat) {
%%var lat = +lat;
%%var lng = +lng;
%%if (out_of_china(lng, lat)) {
%%return [lng, lat]
%%} else {
%%var dlat = transformlat(lng - 105.0, lat - 35.0);
%%var dlng = transformlng(lng - 105.0, lat - 35.0);
%%var radlat = lat / 180.0 * PI;
%%var magic = Math.sin(radlat);
%%magic = 1 - ee * magic * magic;
%%var sqrtmagic = Math.sqrt(magic);
%%dlat = (dlat * 180.0) / ((a * (1 - ee)) / (magic * sqrtmagic) * PI);
%%dlng = (dlng * 180.0) / (a / sqrtmagic * Math.cos(radlat) * PI);
%%var mglat = lat + dlat;
%%var mglng = lng + dlng;
%%return [lng * 2 - mglng, lat * 2 - mglat]
%%}
%%};
gcj02towgs84(Lng, Lat) ->
    case out_of_china(Lng, Lat) of
        true -> [Lng, Lat];
        false ->
            Dlat = transformlat(Lng - 105.0, Lat - 35.0),
            Dlng = transformlng(Lng - 105.0, Lat - 35.0),
            Radlat = Lat / 180.0 * ?PI,
            Magic = math:sin(Radlat),
            Magic1 = 1 - ?EE * Magic * Magic,
            Sqrtmagic = math:sqrt(Magic1),
            Dlat1 = (Dlat * 180.0) / ((?A * (1 - ?EE)) / (Magic1 * Sqrtmagic) * ?PI),
            Dlng1 = (Dlng * 180.0) / (?A / Sqrtmagic * math:cos(Radlat) * ?PI),
            Mglat = Lat + Dlat1,
            Mglng = Lng + Dlng1,
            [Lng * 2 - Mglng, Lat * 2 - Mglat]
    end.


%%var transformlat = function transformlat(lng, lat) {
%%var lat = +lat;
%%var lng = +lng;
%%var ret = -100.0 + 2.0 * lng + 3.0 * lat + 0.2 * lat * lat + 0.1 * lng * lat + 0.2 * Math.sqrt(Math.abs(lng));
%%ret += (20.0 * Math.sin(6.0 * lng * PI) + 20.0 * Math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
%%ret += (20.0 * Math.sin(lat * PI) + 40.0 * Math.sin(lat / 3.0 * PI)) * 2.0 / 3.0;
%%ret += (160.0 * Math.sin(lat / 12.0 * PI) + 320 * Math.sin(lat * PI / 30.0)) * 2.0 / 3.0;
%%return ret
%%};
transformlat(Lng, Lat) ->
    Ret = -100.0 + 2.0 * Lng + 3.0 * Lat + 0.2 * Lat * Lat + 0.1 * Lng * Lat + 0.2 * math:sqrt(abs(Lng)),
    Ret1 = Ret + (20.0 * math:sin(6.0 * Lng * ?PI) + 20.0 * math:sin(2.0 * Lng * ?PI)) * 2.0 / 3.0,
    Ret2 = Ret1 + (20.0 * math:sin(Lat * ?PI) + 40.0 * math:sin(Lat / 3.0 * ?PI)) * 2.0 / 3.0,
    Ret2 + (160.0 * math:sin(Lat / 12.0 * ?PI) + 320 * math:sin(Lat * ?PI / 30.0)) * 2.0 / 3.0.

%%var transformlng = function transformlng(lng, lat) {
%%var lat = +lat;
%%var lng = +lng;
%%var ret = 300.0 + lng + 2.0 * lat + 0.1 * lng * lng + 0.1 * lng * lat + 0.1 * Math.sqrt(Math.abs(lng));
%%ret += (20.0 * Math.sin(6.0 * lng * PI) + 20.0 * Math.sin(2.0 * lng * PI)) * 2.0 / 3.0;
%%ret += (20.0 * Math.sin(lng * PI) + 40.0 * Math.sin(lng / 3.0 * PI)) * 2.0 / 3.0;
%%ret += (150.0 * Math.sin(lng / 12.0 * PI) + 300.0 * Math.sin(lng / 30.0 * PI)) * 2.0 / 3.0;
%%return ret
%%};
transformlng(Lng, Lat) ->
    Ret = 300.0 + Lng + 2.0 * Lat + 0.1 * Lng * Lng + 0.1 * Lng * Lat + 0.1 * math:sqrt(abs(Lng)),
    Ret1 = Ret + (20.0 * math:sin(6.0 * Lng * ?PI) + 20.0 * math:sin(2.0 * Lng * ?PI)) * 2.0 / 3.0,
    Ret2 = Ret1 + (20.0 * math:sin(Lng * ?PI) + 40.0 * math:sin(Lng / 3.0 * ?PI)) * 2.0 / 3.0,
    Ret2 + (150.0 * math:sin(Lng / 12.0 * ?PI) + 300.0 * math:sin(Lng / 30.0 * ?PI)) * 2.0 / 3.0.


%**
%* 判断是否在国内，不在国内则不做偏移
%* @param lng
%* @param lat
%* @returns {boolean}
%*/
% 纬度 3.86~53.55, 经度 73.66~135.05
out_of_china(Lng, Lat) ->
    not ((Lng > 73.66) and (Lng < 135.05) and (Lat > 3.86) and (Lat < 53.55)).


%**
%* 度分格式转度分秒格式
%* @param Lng
%* @param Lat
%* @returns {boolean}
%*/
% 纬度 3.86~53.55, 经度 73.66~135.05
get_deng_gps(Lng, Lat) ->
    LatReal = Lat / 100,
    LatInt = erlang:floor(LatReal),
    LatFrac = (LatReal - LatInt) * 100,
    LatDeg = dgiot_utils:to_float((LatInt + LatFrac / 60), 6),
    LngReal = Lng / 100,
    LngInt = erlang:floor(LngReal),
    LonFrac = (LngReal - LngInt) * 100,
    LngDeg = dgiot_utils:to_float((LngInt + LonFrac / 60), 6),
    [LngDeg, LatDeg].

get_baidu_gps(LonDeg, LatDeg) ->
    [Mglng, Mglat] = wgs84togcj02(LonDeg, LatDeg),
    [Bd_lng, Bd_lat] = gcj02tobd09(Mglng, Mglat),
    [dgiot_utils:to_float(Bd_lng, 6), dgiot_utils:to_float(Bd_lat - 0.0002, 6)].

%%http://lbsyun.baidu.com/index.php?title=webapi/guide/webservice-geocoding-abroad
%<<"http://api.map.baidu.com/reverse_geocoding/v3/?ak=fnc5Z92jC7CwfBGz8Dk66E9sXEIYZ6TG&output=json&coordtype=wgs84ll&location=31.555,120.455">>.
get_baidu_addr(LonDeg, LatDeg) ->
    AppKey = dgiot:get_env(baidumap_appkey),
    get_baidu_addr(AppKey, "wgs84ll", LonDeg, LatDeg).

get_baidu_addr(AK, Coordtype, Lng, Lat) ->
    inets:start(),
    Url = "http://api.map.baidu.com/reverse_geocoding/v3/?ak=" ++ dgiot_utils:to_list(AK) ++
        "&output=json&coordtype=" ++ dgiot_utils:to_list(Coordtype) ++
        "&location=" ++ dgiot_utils:to_list(dgiot_utils:to_binary(Lat)) ++ "," ++ dgiot_utils:to_list(dgiot_utils:to_binary(Lng)),
    case httpc:request(Url) of
        {ok, {{_Version, 200, _ReasonPhrase}, _Headers, Body}} ->
            Json = list_to_binary(Body),
            case jsx:is_json(Json) of
                true ->
                    case jsx:decode(Json, [{labels, binary}, return_maps]) of
                        #{<<"status">> := 0, <<"result">> := Result} ->
                            #{<<"baiduaddr">> => Result};
                        _ -> #{}
                    end;
                false -> #{}
            end;
        _Error ->
            #{}
    end.

%%#  参数含义
%%# base_log：经度基准点，
%%# base_lat：维度基准点，
%%# radius：距离基准点的半径
generate_random_gps(Base_log, Base_lat, Radius) ->
    Radius_in_degrees = Radius / 111300,
    U = random:uniform(100000) div 100000,
    V = random:uniform(100000) div 100000,
    W = Radius_in_degrees * math:sqrt(U),
    T = 2 * ?PI * V,
%%    _X = W * math:cos(T),
    Y = W * math:sin(T),
    Longitude = Y + Base_log,
    Latitude = Y + Base_lat,
%%    # 这里是想保留14位小数
%%    loga = '%.14f' % longitude
%%    lata = '%.14f' % latitude
   {Longitude, Latitude}.
