// SPDX-License-Identifier: MIT OR Apache-2.0
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import http from "node:http";
import path from "node:path";

const [rootArgument, portArgument, host = "127.0.0.1"] = process.argv.slice(2);
if (!rootArgument || !portArgument) {
    console.error("Usage: node static-server.mjs ROOT PORT [HOST]");
    process.exit(2);
}

const root = path.resolve(rootArgument);
const port = Number(portArgument);
const contentTypes = {
    ".arrow": "application/octet-stream",
    ".css": "text/css; charset=utf-8",
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".rrd": "application/octet-stream",
    ".wasm": "application/wasm",
};

const server = http.createServer(async (request, response) => {
    response.setHeader("Access-Control-Allow-Origin", "*");
    response.setHeader("Cache-Control", "no-store");
    if (request.method === "OPTIONS") {
        response.writeHead(204).end();
        return;
    }
    if (!["GET", "HEAD"].includes(request.method)) {
        response.writeHead(405).end();
        return;
    }

    try {
        const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
        if (pathname === "/favicon.ico") {
            response.writeHead(204).end();
            return;
        }
        let filename = path.resolve(root, `.${pathname}`);
        if (filename !== root && !filename.startsWith(`${root}${path.sep}`)) {
            response.writeHead(403).end();
            return;
        }
        let metadata = await stat(filename);
        if (metadata.isDirectory()) {
            filename = path.join(filename, "index.html");
            metadata = await stat(filename);
        }
        if (!metadata.isFile()) {
            response.writeHead(404).end();
            return;
        }
        response.writeHead(200, {
            "Content-Length": metadata.size,
            "Content-Type": contentTypes[path.extname(filename)] ?? "application/octet-stream",
        });
        if (request.method === "HEAD") {
            response.end();
            return;
        }
        const stream = createReadStream(filename);
        stream.on("error", () => response.destroy());
        stream.pipe(response);
    } catch {
        response.writeHead(404).end();
    }
});

server.listen(port, host, () => {
    console.log(`Serving ${root} at http://${host}:${port}`);
});
for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => server.close(() => process.exit(0)));
}
