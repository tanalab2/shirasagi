class Opendata::Harvest::ShirasagiScraper
  attr_accessor :url

  public

  def initialize(url, dataset_search_path = "dataset/search")
    @url = url
    @dataset_search_path = dataset_search_path
    @max_pagination = 10000
  end

  def dataset_search_url
    ::File.join(url, @dataset_search_path, "index.p:page.html")
  end

  def get_dataset_urls
    urls = []
    1.upto(@max_pagination) do |count|
      search_url = dataset_search_url.sub(':page', count.to_s)
      puts search_url

      f = open(search_url, read_timeout: 20)
      html = f.read
      #charset = f.charset
      charset = "utf-8"

      doc = Nokogiri::HTML.parse(html, nil, charset)
      links = doc.css('.opendata-search-datasets.pages article h2 a')
      break if links.blank?

      links.each do |link|
        href = link.attributes["href"]
        next if href.blank?
        urls << ::File.join(url, href.value)
      end
    end
    urls
  end

  def get_dataset(dataset_url)
    dataset = {}

    f = open(dataset_url, read_timeout: 20)
    html = f.read
    #charset = f.charset
    charset = "utf-8"

    doc = Nokogiri::HTML.parse(html, nil, charset)
    doc = doc.css("nav.categories + .text + .dataset-tabs").first.parent

    dataset["url"] = dataset_url
    dataset["name"] = doc.css('header h1.name').text.to_s.strip
    dataset["text"] = doc.css('nav.categories + .text').text.to_s.strip
    dataset["categories"] = doc.css("nav.categories .category").map { |node| node.text.to_s.strip }
    dataset["areas"] = doc.css("nav.categories .area").map { |node| node.text.to_s.strip }

    dt = doc.css(".author dt").select { |node| node.text.to_s.strip == "データ作成者" }.first
    dataset["author"] = dt.css("+ dd").text.to_s.strip if dt

    dataset["updated"] = parse_datetime(doc)

    dataset["resources"] = doc.css(".resources .resource").map do |node|

      dataset["license_title"] ||= doc.css('.license img').first.attributes["alt"].value

      resource = {}
      resource["name"] = node.css(".info .name").text.to_s.strip
      resource["text"] = node.css(".info .text").text.to_s.strip

      href = node.css(".icons a.download").first.attributes["href"].value
      href = ::Addressable::URI.unescape(href)
      resource["url"] = ::File.join(url, href)

      resource["filename"] = ::File.basename(resource["url"])
      resource["format"] = ::File.extname(resource["url"]).downcase.delete(".")

      digits = %w(バイト KB MB GB TB PB)
      bytes, digit = resource["name"].scan(/ ([\d\.]+?)(#{digits.join("|")})\)$/).flatten
      if digits.index(digit)
        resource["display_size"] = (bytes.to_f * (1024 ** digits.index(digit))).to_i
      end
      resource["name"].sub!(/ \(.+?#{bytes}#{digit}\)/, "")

      resource
    end.select { |resource| resource["url"].present? }

    dataset
  end

  private

  def parse_datetime(doc)
    datetime_text = doc.css(".author dd:last").text.to_s.strip

    datetime_array = datetime_text.scan(/(\d+)年(\d+)月(\d+)日 (\d+)時(\d+)分/).flatten
    datetime_array = datetime_text.scan(/(\d+)-(\d+)-(\d+)/).flatten if datetime_array.blank?

    datetime = "#{datetime_array[0]}/#{datetime_array[1]}/#{datetime_array[2]}"
    datetime += " #{datetime_array[3]}:#{datetime_array[4]}" if datetime_array[3] && datetime_array[4]

    Time.zone.parse(datetime)
  end
end