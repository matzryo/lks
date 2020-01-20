
# main.rb create-index
# "渋谷": [3, 5, 7]
#
# インデックス作成
# あっても更新、ただし変わってなければ更新しない
# main.rb read file.csv
#
# (中間処理入るも)
#
# 検索
# main.rb search search-word
require 'zip'
require 'byebug'
require 'open-uri'
require 'csv'
require 'json'

class AddressSearch
  MAX_SIZE = 1024**2*100 # 100MiB
  ZIP_URL = "http://www.post.japanpost.jp/zipcode/dl/kogaki/zip/ken_all.zip"
  DATA_DIRECTORY = "data"
  CSV_ORIGINAL_FILENAME = "KEN_ALL.CSV"
  CSV_ORIGINAL_FILEPATH = [DATA_DIRECTORY, CSV_ORIGINAL_FILENAME].join("/")
  CSV_SHAPED_FILEPATH = [DATA_DIRECTORY, "KEN_ALL_SHAPED.CSV"].join("/")
  ZIP_FILEPATH = [DATA_DIRECTORY, "ken_all.zip"].join("/")
  INDEX_FILEPATH = [DATA_DIRECTORY, "ken_all_indexes.dump"].join("/")

  def prepare
    download_zipfile
    unzip
    shape
    create_index
  end

  def search(search_word)
    unless indexed?
      puts "インデックスを作成します。"
      create_index
    end

    # 1文字のときはどうする?
    bi_gram = search_word.each_char.each_cons(2).map(&:join)
    indexes =
        File.open(INDEX_FILEPATH) do |io|
          Marshal.load(io)
        end
    matched = nil
    bi_gram.each do |two_chars|
      if lines = indexes[two_chars]
        matched ||= Set.new(lines)
        matched = matched & Set.new(lines)
      end
      matched
    end
    csv = File.open(CSV_SHAPED_FILEPATH).readlines
    matched.each do |i|
      puts csv[i]
    end
    if matched.empty?
      puts "該当無し"
    end
  end

  private

  def download_zipfile
    puts "DL中…"
    File.open(ZIP_FILEPATH, "w") do |f|
      data = URI.open(ZIP_URL).read
      f.write data
    end
  end

  def unzip
    puts "解凍中…"
    Zip::File.open(ZIP_FILEPATH) do |zip_file|
      # ファイル名指定しちゃっていいのかな
      entry = zip_file.glob(CSV_ORIGINAL_FILENAME).first

      raise 'File too large when extracted' if entry.size > MAX_SIZE

      if File.exist?(CSV_ORIGINAL_FILEPATH)
        File.delete(CSV_ORIGINAL_FILEPATH)
      end

      entry.extract(CSV_ORIGINAL_FILEPATH)
    end
  end

  # 参考: http://zipcloud.ibsnet.co.jp/
  def shape
    puts "整形中…"
    merge_buffer = []
    # 文字コード変換
    CSV.open(CSV_SHAPED_FILEPATH, 'wt') do |shaped_file|
      rows = CSV.read(CSV_ORIGINAL_FILEPATH, encoding: "CP932:UTF-8")
      rows.each_with_index do |row, i|
        # 町域名が「以下に掲載がない場合」の場合は、ブランク（空文字）に置換
        if row[8] === "以下に掲載がない場合"
          row[8] = ""
        end

        # 町域名が「○○市（または町・村）の次に番地がくる場合」の場合は、ブランク（空文字）に置換
        if row[8].match(/の次に番地がくる場合/)
          row[8] = ""
        end

        # 町域名が「○○市（または町・村）一円」の場合は、ブランク（空文字）に置換
        # ※ただし「一円」が地名である場合は置換しません。
        if row[8].match(/.+一円/)
          row[8] = ""
        end

        # 次の行も同じならマージする
        # ただしこのやりかただと同音異名の地名(前沢谷記と前沢谷起、横マクリと横まくり等)をマージしてしまう
        merge_buffer << row

        # 次の行が現在の行と町域以外同じときはマージ対象とする
        if (i < rows.length - 1) && (row[0...8] === rows[i+1][0...8]) && (row[9...15] === rows[i+1][9...15])
            next
        else
          merged = merge_buffer.first[0...8] + [merge_buffer.inject("") {|memo, item| memo + item[8]}] + merge_buffer.first[9...15]
          merge_buffer = []
        end

        shaped_file << merged
      end
    end
  end

  def create_index
    puts "インデックス作成中…"
    indexes = {}

    CSV.foreach(CSV_SHAPED_FILEPATH).with_index do |row, index|
      # 住所の箇所を抜き出して繋げてbi-gram
      bi_gram = row.slice(6..8).join.each_char.each_cons(2).map(&:join)
      bi_gram.each do |word|
        unless indexes.has_key?(word)
          indexes[word] = []
        end
        indexes[word].push(index)
      end
    end
    File.open(INDEX_FILEPATH, 'w') do |io|
      Marshal.dump(indexes, io)
    end
  end

  def indexed?
    File.exist?(INDEX_FILEPATH)
  end
end

def help
  help = <<~HELP
    インデックス作成
    ruby main.rb prepare

    検索
    ruby main.rb search SEARCH_WORD
  HELP
  puts help
end

address_search = AddressSearch.new

subcommand = ARGV.shift

case subcommand
when "prepare"
  unless ARGV.empty?
    raise ArgumentError, "引数の指定が不正です。"
  end
  address_search.prepare
when "search"
  search_word = ARGV.shift
  unless ARGV.empty?
    raise ArgumentError, "引数の指定が不正です。"
  end
  address_search.search(search_word)
else
  help
end
