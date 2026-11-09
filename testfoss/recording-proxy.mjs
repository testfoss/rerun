import {createReadStream} from "node:fs";
import {createServer, request} from "node:http";

const port = Number(process.argv[2] || 8104);
const target = new URL(process.env.TESTFOSS_VIEWER_TARGET || "http://127.0.0.1:8102");
const recording = process.env.TESTFOSS_RECORDING_FILE;
if (!recording) throw new Error("TESTFOSS_RECORDING_FILE is required");

createServer((req, res) => {
  if (req.url === "/example.rrd") {
    res.writeHead(200, {"content-type": "application/octet-stream", "cache-control": "no-store"});
    createReadStream(recording).pipe(res);
    return;
  }
  const upstream = request(new URL(req.url, target), {
    method: req.method,
    headers: {...req.headers, host: target.host},
  }, response => {
    res.writeHead(response.statusCode || 502, response.headers);
    response.pipe(res);
  });
  upstream.on("error", error => {
    res.writeHead(502, {"content-type": "text/plain"});
    res.end(`viewer proxy: ${error.message}`);
  });
  req.pipe(upstream);
}).listen(port, "127.0.0.1", () => {
  console.log(`same-origin recording proxy at http://127.0.0.1:${port}`);
});
