class SourceController < ApplicationController

  def source
    git_rev = `git rev-parse --verify HEAD`.strip
    public_name = "block_browser-#{git_rev[0..8]}"
    tar_file = File.join(Rails.root, "public/#{public_name}.tar.bz2")
    unless File.exist?(tar_file)
      tmpdir = Dir.mktmpdir
      Dir.mkdir(File.join(tmpdir, public_name))
      `git clone . #{tmpdir}/#{public_name}`
      Dir.chdir(File.join(tmpdir, public_name)) { `git checkout #{git_rev}` }
      Dir.chdir(tmpdir) { `tar -cjf #{tar_file} #{public_name}` }
      FileUtils.rm_rf tmpdir
    end
    redirect_to "/#{public_name}.tar.bz2"
  end

end
