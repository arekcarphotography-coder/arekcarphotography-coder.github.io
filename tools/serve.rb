# Lokalny serwer strony (zamiast `ruby -run -e httpd`).
# Różnica: każe przeglądarce zawsze sprawdzać, czy plik się zmienił (Cache-Control: no-cache),
# więc po zmianach na stronie wystarczy zwykłe odświeżenie — bez starych plików z pamięci przeglądarki.
# Użycie (w folderze strony):  ruby tools/serve.rb   → http://localhost:8080
require "webrick"

port = (ARGV[0] || 8080).to_i
root = File.expand_path("..", __dir__)
server = WEBrick::HTTPServer.new(Port: port, DocumentRoot: root,
  AccessLog: [], Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))

# Doklejamy nagłówek do każdej odpowiedzi
module NoCache
  def do_GET(req, res)
    super
    res["Cache-Control"] = "no-cache"
  end
end
WEBrick::HTTPServlet::FileHandler.prepend(NoCache)

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }
puts "Strona działa: http://localhost:#{port}  (zatrzymanie: Ctrl+C)"
server.start
