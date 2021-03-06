xquery version "1.0-ml";

(:
 : Copyright (c) 2011-2013 Michael Blakeley. All Rights Reserved.
 :
 : Licensed under the Apache License, Version 2.0 (the "License");
 : you may not use this file except in compliance with the License.
 : You may obtain a copy of the License at
 :
 : http://www.apache.org/licenses/LICENSE-2.0
 :
 : Unless required by applicable law or agreed to in writing, software
 : distributed under the License is distributed on an "AS IS" BASIS,
 : WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 : See the License for the specific language governing permissions and
 : limitations under the License.
 :
 : The use of the Apache License does not indicate that this project is
 : affiliated with the Apache Software Foundation.
 :
 :)

import module namespace trb="com.blakeley.task-rebalancer"
  at "lib-trb.xqy" ;

declare namespace fs="http://marklogic.com/xdmp/status/forest";
declare namespace hs="http://marklogic.com/xdmp/status/host" ;
declare namespace ss="http://marklogic.com/xdmp/status/server" ;

declare variable $LIMIT as xs:integer external ;

declare variable $MODULE as xs:string external ;

declare variable $RESPAWN as xs:boolean external ;

declare variable $FORESTS-MAP := trb:forests-map() ;

(: Make sure uri lexicon is enabled. :)
cts:uris((), 'limit=0'),
(: NB - cannot check trb:maybe-fatal,
 : because the state is only set on the task server
 :)

(: Make sure we have at least one task server thread per local forest.
 : This prevents forest-uris respawning from deadlocking the task server.
 :)
let $host := xdmp:host()
let $tid := xdmp:host-status($host)/hs:task-server/hs:task-server-id
let $threads := xdmp:server-status($host, $tid)/ss:max-threads/data(.)
let $assert := (
  if (not($RESPAWN)) then ()
  else if (count(map:keys($FORESTS-MAP)) lt $threads) then ()
  else error(
    (), 'TRB-TOOFEWTHREADS',
    text {
      'to avoid deadlocks,',
      'configure the task server with at least',
      1 + count(map:keys($FORESTS-MAP)), 'threads' }))
(: Clear any state if respawn is set.
 : If respawn is not set, this may be a scheduled task.
 :)
let $_ := if (not($RESPAWN)) then () else (
  for $key in map:keys($FORESTS-MAP)
  return xdmp:spawn(
    'uris-start-unset.xqy',
    (xs:QName('FOREST'), xdmp:forest-name(xs:unsignedLong($key)))))
for $key in map:keys($FORESTS-MAP)
let $x := map:get($FORESTS-MAP, $key)
let $fid := xs:unsignedLong($key)
let $estimate := xdmp:estimate(
  cts:search(doc(), cts:and-query(()), (), (), $fid))
(: give larger forests a head start :)
order by $estimate descending
return (
  xdmp:forest-name($fid),
  xdmp:spawn(
    $MODULE,
    (xs:QName('FOREST'), $fid,
      xs:QName('INDEX'), $x,
      xs:QName('LIMIT'), $LIMIT,
      xs:QName('RESPAWN'), $RESPAWN),
      <options xmlns="xdmp:eval"><time-limit>3600</time-limit></options>),
  (: Allow ramp-up time, 1-ms per 2000 docs.
   : NB - with default time limit, this will time out around 1B docs.
   : If this happens, raise the time limit.
   :)
  xdmp:sleep($estimate idiv 2000))

(: forests.xqy :)
