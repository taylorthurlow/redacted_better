require "faraday"
require "faraday_middleware"

module RedactedBetter
  class Yadg
    YADG_BASE_URL = "https://yadg.cc".freeze

    # @return [String]
    attr_reader :api_key

    # @param api_key [String]
    def initialize(api_key)
      @api_key = api_key
    end

    # @return [String]
    def description(url)
      response = api_connection.post("api/v2/query/") do |request|
        request.body = { input: url, scraper: nil }.to_json
      end

      result_id = JSON.parse(response.body).fetch("resultId")

      description = nil
      try_count = 0
      until description
        try_count += 1
        response = api_connection.get("api/v2/result/#{result_id}")

        data = JSON.parse(response.body)

        if data.fetch("status") == "done"
          tmpdir = Dir.mktmpdir

          swig_json_input_file = File.open(File.join(tmpdir, "data.json"), "w+") do |f|
            f.write(response.body)
            f.path
          end
          swig_template_input_file = File.open(File.join(tmpdir, "template.swig"), "w+") do |f|
            f.write(swig_template)
            f.path
          end

          stdout, stderr, status = Open3.capture3(
            "npm exec -- \
               swig render \
                 --filters \"#{swig_filters_path}\" \
                 --json \"#{swig_json_input_file}\" \
                 \"#{swig_template_input_file}\"",
          )

          unless status.success?
            warn Pastel.new.yellow(stderr)
            raise "Swig template generator failed!"
          end

          description = stdout
        elsif try_count < 5
          sleep(2)
          next
        else
          raise "YADG result not finishing, something is wrong."
        end
      end

      description
    end

    # @return [Array<Hash>] a map between pretty scraper names (keys)
    #   and their API values (values)
    def available_scrapers
      response = api_connection.get("api/v2/scrapers")

      JSON.parse(response.body).map do |scraper|
        {
          name: scraper.fetch("name"),
          value: scraper.fetch("value"),
        }
      end
    end

    # @return [Faraday::Connection]
    def api_connection
      Faraday.new(
        YADG_BASE_URL,
        headers: {
          "Authorization" => "Token #{api_key}",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
        },
      ) do |f|
        f.use Faraday::Response::RaiseError
        f.use FaradayMiddleware::FollowRedirects
      end
    end

    private

    # @return [String]
    def swig_template
      <<~SWIG
        [size=4][b]{% set main_artists=data.artists|artistsbytype("main") %}{{ main_artists|wrap("%s",", ", " & ") }}{% set featured_artists=data.artists|artistsbytype("guest") %}{% if featured_artists.length > 0 %} feat. {{ featured_artists|wrap("%s",", ", " & ") }}{% endif %} – {{ data.title }}[/b][/size]

        {% if data.labelIds.length > 0 %}[b]Label/Cat#:[/b] {% for labelId in data.labelIds %}{{ labelId.label }}{% if labelId.catalogueNrs.length > 0 %} – {{ labelId.catalogueNrs|join(" or ") }}{% endif %}{% if not loop.last %}, {% endif %}{% endfor %}
        {% endif %}{% if data.releaseEvents.length > 0 %}{% set releaseEvent=data.releaseEvents|first %}{% if releaseEvent.country %}[b]Country:[/b] {{ releaseEvent.country }}
        {% endif %}{% if releaseEvent.date %}[b]Year:[/b] {{ releaseEvent.date }}
        {% endif %}{% endif %}{% if data.genres.length > 0 %}[b]Genre:[/b] {{ data.genres|join(", ") }}
        {% endif %}{% if data.styles.length > 0  %}[b]Style:[/b] {{ data.styles|join(", ") }}
        {% endif %}{% if data.format %}[b]Format:[/b] {{ data.format }}
        {% endif %}
        {% if data.discs.length == 1 %}[size=3][b]Tracklist[/b][/size]
        {% endif %}{% for disc in data.discs %}{% if data.discs.length > 1 %}{% if not loop.first %}
        
        {% endif %}[size=3][b]Disc {{ disc.number }}{% if disc.title %}: [i]{{ disc.title }}[/i]{% endif %}[/b]{% if data.discs.length > 1 %}{% set disc_length=0 %}{% for track in disc.tracks %}{% if track.length %}{% set disc_length=disc_length+track.length %}{% endif %}{% endfor %}{% if disc_length > 0 %} ({{ disc_length|formatseconds(true) }}){% endif %}{% endif %}[/size]
        {% endif %}{% for track in disc.tracks %}[b]{{ track.number }}{% if track.number|isdigit %}.[/b]{% else %}[/b] –{% endif %}{% set main_track_artists=track.artists|artistsbytype("main") %}{% if main_track_artists.length > 0 %} {{ main_track_artists|wrap("%s",", ", " & ") }} –{% endif %} {{ track.title }}{% set feature=track.artists|artistsbytype("guest") %}{% if feature.length > 0 %} (feat. {{ feature|wrap("%s",", ", " & ") }}){% endif %}{% if track.length %} [i]({{ track.length|formatseconds(true) }})[/i]{% endif %}{% if not loop.last %}
        {% endif %}{% endfor %}{% endfor %}{% set total_length=0 %}{% for disc in data.discs %}{% for track in disc.tracks %}{% if track.length %}{% set total_length=total_length+track.length %}{% endif %}{% endfor %}{% endfor %}{% if total_length > 0 %}
        
        [b]Total length:[/b] {{ total_length|formatseconds(true) }}{% endif %}{% if data.url %}
        
        More information: [url]{{ data.url }}[/url]{% endif %}
      SWIG
    end

    # @return [String]
    def swig_filters_path
      File.join(RedactedBetter.root, "yadg_swig_filters.js")
    end
  end
end
