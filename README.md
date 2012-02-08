Task Server Scripts for Forest Rebalancing
===

Sometimes a MarkLogic Server database will have several forests.
If the forests are present from the time when the database was created,
they will each have approximately the same number of forests.
But if the administrator adds more forests later on,
the newer forests will tend to have fewer documents.
In cases like this, we can rebalance the forests.

But before using this tool, consider that
rebalancing is generally slower than clearing the database and reloading.
That is because many documents must be updated,
and updates are more expensive than inserts.
So rebalancing the forests may not be the best way to solve the problem.
If you have the luxury of clearing the database and reloading everything, do it.

Finally, note that following this procedure may result in forests
containing many deleted fragments. To recover disk space,
you may wish to force some forests to merge.

Setup
---

This project contains three XQuery modules,
intended for use with the built-in Task Server.

* `forests.xqy`: entry point for `xdmp:invoke`, HTTP request, or scheduled task.
* `forest-uris.xqy`: spawned by `forests.xqy` to rebalance one forest.
* `rebalance.xqy`: spawned by `forest-uris.xqy` to move one document.

The database that you wish to rebalance must have the URI lexicon enabled.
If that lexicon is not enabled, you must enable it and reindex.
In that case you may be better off reloading all your content (see above).

Usage
---

    xdmp:invoke(
      'forests.xqy',
      (xs:QName('LIMIT'), 0),
      <options xmlns="xdmp:eval">
        <database>{ xdmp:database('DATABASE-NAME') }</database>
        <root>/PATH/TO/XQY/FILES/</root>
      </options>)

Note that `forest-uris.xqy` and `rebalance.xqy` will run on the Task Server.
By default, the Task Server thread pool size is 4.
If your host has more than 4 CPU cores,
you may wish to increase the thread pool size to match.
However, you can also use the Task Server thread pool size
to throttle the impact of the rebalance tasks
on other users of the system.

Note that `forests.xqy` will only spawn `forest-uris.xqy`
for forests local to the host. This is done so that
you can invoke `forests.xqy` on each host in your cluster.
This improves concurrency in clustered environments.

Troubleshooting
---

Because most of the work happens on the Task Server,
most error messages will only appear in the `ErrorLog.txt` file.
You may wish to increase the log-level to Debug to aid any troubleshooting.

The error code `XDMP-URILXCNNOTFOUND` means that the selected database
does not have a URI lexicon enabled. If you recently enabled the uri lexicon,
make sure the database has been allowed to reindex.

Note that this tool does not attempt to balance on-disk size.
Instead, it uses `xdmp:document-assign` to ensure that each document
is in the correct forest for its document URI.

Detaching and reattaching forests may cause the order of the forests
from `xdmp:document-forests` to change. If this happens,
`xdmp:document-assign` may want to reassign documents to different forests.
For predicatable results, try to ensure that the forests as listed
in the admin UI Database > Forests are in some determinate order:
for example, keep the forests alphabetized.

If this tool runs out of control, use the following expression to halt it:

    xdmp:spawn(
      'disable.xqy',
      (),
      <options xmlns="xdmp:eval">
        <database>{ xdmp:database() }</database>
        <root>/PATH/TO/XQY/FILES/</root>
      </options>)

Watch the Task Server status page. Once all the tasks have finished,
use this expression to renable the rebalancer.

    xdmp:spawn(
      enable.xqy',
      (),
      <options xmlns="xdmp:eval">
        <database>{ xdmp:database() }</database>
        <root>/PATH/TO/XQY/FILES/</root>
      </options>)

You can also try to stop it by moving the `task-rebalancer` directory aside.
Either of these techniques may take some time: if you are in a hurry,
it may be faster to restart MarkLogic on the affected host.

License
---
Copyright (c) 2011-2012 Michael Blakeley. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

The use of the Apache License does not indicate that this project is
affiliated with the Apache Software Foundation.

