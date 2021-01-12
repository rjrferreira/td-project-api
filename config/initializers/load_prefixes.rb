PREFIXES = []
File.open("prefixes.txt", "r") do |f|
  f.each_line do |line|
    PREFIXES << line.strip if line.length > 0
  end
end
PREFIXES = PREFIXES.uniq