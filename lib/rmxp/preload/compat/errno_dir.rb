# Sous Windows, ouvrir un dossier avec File.open lève EACCES ; sous Linux,
# EISDIR. Les jeux Essentials ne rescapent souvent que EACCES/ENOENT.
class << File
  alias __rmxp_file_open open unless method_defined?(:__rmxp_file_open)
  def open(path, *args, &block)
    __rmxp_file_open(path, *args, &block)
  rescue Errno::EISDIR
    raise Errno::EACCES, path.to_s
  end
end
