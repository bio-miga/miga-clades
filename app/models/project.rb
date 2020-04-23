require 'miga/common'

class Project < ApplicationRecord
  belongs_to :user
  has_many :query_datasets, dependent: :destroy
  attr_accessor :miga_obj, :code
  validates :user_id, presence: true
  validates :path, presence: true, miga_name: true,
    uniqueness: { case_sensitive: false }
  validates :private, presence: true
  before_save :create_miga_project
  default_scope -> { order(path: :asc) }

  def path_name
    path.tr('_',' ')
  end

  def miga
    load_miga_project
    miga_obj
  end

  def daemon_last_alive
    require 'miga/daemon'
    return nil if miga.nil?
    MiGA::Daemon.last_alive miga
  end

  def daemon_active?
    MiGA::Daemon.new(miga).active?
  end

  def ref_datasets
    return [] if miga.nil?
    miga.metadata[:datasets].reject{ |n| n =~ /^qG_.*_u\d+$/ }
  end

  def code
    @code ||= path =~ /.[A-Z]/ ?
      path.gsub(/^(.)(?:[^A-Z]*)([A-Z]).*/,"\\1\\2") :
      path.gsub(/^(.)(?:[^_]*_)?(.).*/,"\\1\\2")
  end

  def code_base_color
    sprintf('%06x', (XXhash.xxh32(path,6) % (16**6)))
  end
   
  def code_color
    c = Color::RGB.by_hex(code_base_color).to_hsl
    c.luminosity = 40 + c.luminosity/4
    c.saturation = 40 + c.saturation/4
    c.css_hsl
  end

  def code_light_color
    c = Color::RGB.by_hex(code_base_color).to_hsl
    c.luminosity = 90 + c.luminosity/10
    c.saturation = 40 + c.saturation/4
    c.css_hsl
  end

  def dataset_counts(user)
    return { ref:0, qry:0, qry_yes:0, qry_no:0 } if user.nil?
    qd = QueryDataset.by_user_and_project(user, self)
    o = { ref: ref_datasets.count }
    o[:qry] = qd.count
    o[:qry_yes] = qd.select{ |qd| qd.ready? }.count
    o[:qry_no]  = o[:qry] - o[:qry_yes]
    o
  end

  def ncbi_download!(species, codes)
    cmd = [
      'ncbi_get', '--project', miga.path, '--taxon', species
    ] + codes.map { |i| "--#{i}" }
    logger.info("Launching CLI: #{cmd}")
    
    Spawnling.new(argv: "miga-web-spawn -#{path_name}-") do
      require 'miga/cli'
      MiGA::Cli.new(cmd).launch
      logger.info("Project #{id}: Downloaded reference genomes")
    end
    true
  end

  # Returns the RDP classification of dataset with name +ds_name+ using RDP
  # SOAP services.
  def rdp_classify(ds_name)
    ds_miga = miga.dataset(ds_name)
    return if ds_miga.nil?
    res = ds_miga.result(:ssu)
    return if res.nil?
    file = res.file_path(:all_ssu_genes)
    file = res.file_path(:longest_ssu_gene) if file.nil?
    return if file.nil?
    seq = (file =~ /\.gz$/ ? Zlib::GzipReader : File).open(file).read
    wsdl = "http://rdp.cme.msu.edu:80/services/classifier?wsdl"
    client = Savon.client(wsdl: wsdl)
    client.call(:classifier, message: seq)
  end

  def readme_file
    File.expand_path('README.md', full_path)
  end

  def last_db_update
    return if miga.nil?
    res = miga.result(:subclades)
    res ||= miga.result(:clade_finding)
    return if res.nil?
    DateTime.parse res[:updated]
  end

  private

  def full_path
    dir = Settings.miga_projects
    unless official?
      dir = File.join(dir, 'user-contributed', user.id.to_s)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end
    File.join(dir, path)
  end

  def create_miga_project
    project = MiGA::Project.new(full_path)
    project.metadata[:user] = user.id
    project.save
  end

  def load_miga_project
    @miga_obj ||= MiGA::Project.load(full_path)
  end
end
