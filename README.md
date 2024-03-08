# web-server
 Simple Web Server made in Zig

### Features

- Static only
- *Hot reloading

### Routing
Target routes are passed into a StringHashMap. <br>
If target route is found a function ptr is returned which the handler can get assets from that route.

### Notes

- You have to add routes for them to be found in main.main().zig <br>
- You have to deinit and init each page in main.reload().zig for hot reload to work
- Hot reloading only reloads a file which has been modified in the last 3 minutes when you send a request