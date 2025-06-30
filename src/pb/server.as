auto server_initializer = startnew(Server::StartHttpServer);

namespace Server {
    const uint PORT = 29918;
    const string HOSTNAME = "127.0.0.1";

    const string HTTP_BASE_URL = "http://" + HOSTNAME + ":" + PORT + "/";

    const string serverDir = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/");
    const string serverDirectoryAutoMove = IO::FromUserGameFolder("Replays/zzAutoEnablePBGhost/tmp/");

    HttpServer@ server = null;

    enum ServerState {
        NotStarted,
        Running,
        Shutdown,
        Error
    }

    void StartHttpServer() {
        if (server !is null) return;
        @server = HttpServer(HOSTNAME, PORT);
        @server.RequestHandler = RouteRequests;
        server.StartServer();
    }

    HttpResponse@ RouteRequests(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
        log("Route: " + route, LogLevel::Info, 59, "StartHttpServer");
        log("Data length: " + data.Length, LogLevel::Info, 60, "StartHttpServer");
        if (route.StartsWith('/get_ghost/')) return HandleGetGhost(type, route, headers, data);
        log("Did not find route.", LogLevel::Warn, 62, "StartHttpServer");
        return _404_Response;
    }

    HttpResponse@ HandleGetGhost(const string &in type, const string &in route, dictionary@ headers, const string &in data) {
        if (type != "GET") return HttpResponse(405, "Must be a GET request.");
        if (!route.StartsWith("/get_ghost/")) return _404_Response;
        try {
            auto key = Net::UrlDecode(route.Replace("/get_ghost/", ""));
            log('loading ghost: ' + key, LogLevel::Info, 71, "StartHttpServer");
            string filePath = serverDirectoryAutoMove + key;
            if (!IO::FileExists(filePath)) return _404_Response;
            auto buf = _IO::File::ReadFileToEnd(filePath);
            log('got buf: ' + buf.Length, LogLevel::Info, 75, "StartHttpServer");
            return HttpResponse(200, buf);
        } catch {
            log("Exception in HandleGetGhost: " + getExceptionInfo(), LogLevel::Error, 78, "StartHttpServer");
        }
        return HttpResponse(500, "Internal Server Error");
    }

    HttpResponse _404_Response(404, "Not found");

    class HttpResponse {
        int status = 405;
        string _body;
        MemoryBuffer@ _buf;
        dictionary headers;

        string body {
            get { return _body; }
        }

        void set_body(const string &in value) {
            _body = value;
            headers['Content-Length'] = tostring(value.Length);
        }

        HttpResponse() {
            InitHeaders(0);
        }
        HttpResponse(int status, const string &in body = "") {
            InitHeaders(body.Length);
            this.status = status;
            this.body = body;
        }
        HttpResponse(int status, MemoryBuffer@ buf) {
            InitHeaders(buf.GetSize(), "application/octet-stream");
            this.status = status;
            @_buf = buf;
        }

        protected void InitHeaders(uint contentLength, const string &in contentType = "text/plain") {
            headers['Content-Length'] = tostring(contentLength);
            headers['Content-Type'] = contentType;
            headers['Server'] = "AngelScript HttpServer " + Meta::ExecutingPlugin().Version;
            headers['Connection'] = "close";
        }

        const string StatusMsgText() {
            switch (status) {
                case 200: return "OK";
                case 404: return "Not Found";
                case 405: return "Method Not Allowed";
                case 500: return "Internal Server Error";
            }
            if (status < 300) return "OK?";
            if (status < 400) return "Redirect?";
            if (status < 500) return "Request Error?";
            return "Server Error?";
        }
    }

    // Returns status
    funcdef HttpResponse@ ReqHandlerFunc(const string &in type, const string &in route, dictionary@ headers, const string &in data);

    /* An http server. Call `.StartServer()` to start listening. Default port is 29805 and default host is localhost. */
    class HttpServer {
        // 29805 = 0x746d = 'tm'
        uint16 port = 29806;
        string host = "localhost";
        protected ServerState state = ServerState::NotStarted;

        HttpServer() {}
        HttpServer(uint16 port) {
            this.port = port;
        }
        HttpServer(const string &in hostname) {
            this.host = hostname;
        }
        HttpServer(const string &in hostname, uint16 port) {
            this.port = port;
            this.host = hostname;
        }

        protected Net::Socket@ socket = null;
        ReqHandlerFunc@ RequestHandler = null;

        void Shutdown() {
            state = ServerState::Shutdown;
            try {
                socket.Close();
            } catch {}
            log("Server shut down.", LogLevel::Info, 165, "Shutdown");
        }

        void StartServer() {
            if (RequestHandler is null) {
                throw("Must set .RequestHandler before starting server!");
            }
            if (state != ServerState::NotStarted) {
                throw("Cannot start HTTP server twice.");
            }
            @socket = Net::Socket();
            log("Starting server: " + host + ":" + port, LogLevel::Info, 176, "StartServer");
            if (!socket.Listen(host, port)) {
                SetError("failed to start listening");
                return;
            }
            state = ServerState::Running;
            log("Server running.", LogLevel::Info, 182, "StartServer");
            startnew(CoroutineFunc(this.AcceptConnections));
        }

        protected void SetError(const string &in errMsg) {
            log('HttpServer terminated with error: ' + errMsg, LogLevel::Error, 187, "SetError");
            state = ServerState::Error;
            try {
                socket.Close();
            } catch {};
            @socket = null;
        }

        protected void AcceptConnections() {
            while (state == ServerState::Running) {
                yield();
                auto client = socket.Accept();
                if (client is null) continue;
                log("Accepted new client // Remote: " + client.GetRemoteIP(), LogLevel::Info, 200, "AcceptConnections");
                startnew(CoroutineFuncUserdata(this.RunClient), client);
            }
        }

        protected void RunClient(ref@ clientRef) {
            auto client = cast<Net::Socket>(clientRef);
            if (client is null) return;
            uint clientStarted = Time::Now;
            while (Time::Now - clientStarted < 10000 && client.Available() == 0) yield();
            if (client.Available() == 0) {
                log("Timing out client: " + client.GetRemoteIP(), LogLevel::Info, 211, "RunClient");
                client.Close();
                return;
            }
            RunRequest(client);
            log("Closing client.", LogLevel::Info, 216, "RunClient");
            client.Close();
        }

        protected void RunRequest(Net::Socket@ client) {
            string reqLine;
            if (!client.ReadLine(reqLine)) {
                log("RunRequest: could not read first line!", LogLevel::Warn, 223, "RunRequest");
                return;
            }
            reqLine = reqLine.Trim();
            auto reqParts = reqLine.Split(" ", 3);
            log("RunRequest got first line: " + reqLine + " (parts: " + reqParts.Length + ")", LogLevel::Info, 228, "RunRequest");
            auto headers = ParseHeaders(client);
            log("Got " + headers.GetSize() + " headers.", LogLevel::Info, 230, "RunRequest");
            // auto headerKeys = headers.GetKeys();
            auto reqType = reqParts[0];
            auto reqRoute = reqParts[1];
            auto httpVersion = reqParts[2];
            if (!httpVersion.StartsWith("HTTP/1.")) {
                log("Unsupported HTTP version: " + httpVersion, LogLevel::Warn, 236, "RunRequest");
                return;
            }
            string data;
            if (headers.Exists('Content-Length')) {
                auto len = Text::ParseInt(string(headers['Content-Length']));
                data = client.ReadRaw(len);
            }
            if (client.Available() > 0) {
                log("After reading headers and body there are " + client.Available() + " bytes remaining!", LogLevel::Warn, 245, "RunRequest");
            }
            HttpResponse@ resp = HttpResponse();
            try {
                @resp = RequestHandler(reqType, reqRoute, headers, data);
            } catch {
                log("Exception in RequestHandler: " + getExceptionInfo(), LogLevel::Error, 251, "RunRequest");
                resp.status = 500;
                resp.body = "Exception: " + getExceptionInfo();
            }
            string respHdrsStr = FormatHeaders(resp.headers);
            string fullResponse = httpVersion + " " + resp.status + " " + resp.StatusMsgText() + "\r\n" + respHdrsStr;
            fullResponse += "\r\n\r\n" + resp.body;
            auto respBuf = MemoryBuffer();
            respBuf.Write(fullResponse);
            log("Response: " + fullResponse, LogLevel::Debug, 260, "RunRequest");
            if (resp._buf !is null) {
                resp._buf.Seek(0);
                respBuf.WriteFromBuffer(resp._buf, resp._buf.GetSize());
            }
            // need to use WriteRaw b/c otherwise strings are length prefixed
            // client.WriteRaw(fullResponse);
            respBuf.Seek(0);
            client.Write(respBuf, respBuf.GetSize());
            log("["+Time::Stamp + " | " + client.GetRemoteIP()+"] " + reqType + " " + reqRoute + " " + resp.status, LogLevel::Info, 269, "RunRequest");
            log("Completed request.", LogLevel::Info, 270, "RunRequest");
        }

        protected dictionary@ ParseHeaders(Net::Socket@ client) {
            dictionary headers;
            string nextLine;
            while (true) {
                while (client.Available() == 0) yield();
                client.ReadLine(nextLine);
                nextLine = nextLine.Trim();
                if (nextLine.Length > 0) {
                    AddHeader(headers, nextLine);
                } else break;
            }
            return headers;
        }

        protected void AddHeader(dictionary@ d, const string &in line) {
            auto parts = line.Split(":", 2);
            if (parts.Length < 2) {
                log("Header line failed to parse: " + line + " // " + parts[0], LogLevel::Warn, 290, "AddHeader");
            } else {
                d[parts[0]] = parts[1];
                if (parts[0].ToLower().Contains("authorization")) {
                    parts[1] = "<auth omitted>";
                }
                log("Parsed header line: " + parts[0] + ": " + parts[1], LogLevel::Info, 296, "AddHeader");
            }
        }
    }

    string FormatHeaders(dictionary@ headers) {
        auto keys = headers.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            if (keys[i].ToLower().Contains("authorization")) {
                keys[i] += ": <auth omitted>";
            } else {
                keys[i] += ": " + string(headers[keys[i]]);
            }
        }
        return string::Join(keys, "\r\n");
    }
}