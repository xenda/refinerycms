begin
  require 'zip/zip'
  require 'zip/zipfilesystem'
rescue LoadError => load_error
  # Otherwise, this will stop rake tasks running
  "*** rubyzip gem needs to be installed to use themes. ***"
end

class Theme < ActiveRecord::Base

	before_save :read_theme

  has_attachment :storage => (USE_S3_BACKEND ? :s3 : :file_system),
          			 :size => 0.kilobytes..15.megabytes,
								 :path_prefix => (USE_S3_BACKEND ? nil : 'public/system/themes'),
								 :content_type => 'application/zip'

	# Once a zip is uploaded it unzips it into the themes directory if writable
	def after_attachment_saved
		if Theme::directory_is_writable?
			# make the folder for the them
			FileUtils.mkdir(self.theme_path) unless File.exists? self.theme_path

			# extracts the contents of the zip file into the theme directory
		 	Zip::ZipFile.foreach(self.filename) do |entry|
				FileUtils.mkdir_p(File.dirname("#{theme_path}/#{entry}"))
				entry.extract("#{theme_path}/#{entry}") { true }
		  end
		else
			raise "Theme directory not writable"
		end
	end

	def theme_folder_title
		File.basename(self.filename).split(".").first
	end

	def theme_path
		File.join(RAILS_ROOT, "themes", theme_folder_title)
	end

	def preview_image
		File.join(theme_path, "preview.png")
	end

	def read_theme
		self.title = File.basename(self.filename).split(".").first.titleize

		if File.exists? File.join(theme_path, "LICENSE")
			self.license =  File.open(File.join(theme_path, "LICENSE")).read
		end

		if File.exists? File.join(theme_path, "README")
			self.description =  File.open(File.join(theme_path, "README")).read
		end
	end

	def self.directory_is_writable?
		File.writable? File.join(RAILS_ROOT, "themes") # Heroku users will receive false here
	end

end