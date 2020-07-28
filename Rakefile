task :default => ['build']

desc 'Build the task image'
task :build, [:image, :tag, :auto_latest] do |task, args|
  args.with_defaults(image: 'oracle_hcm_clm_sync', tag: 'latest', auto_latest: true)
  tags = ["#{args.image}:#{args.tag}"]
  if args.tag != 'latest' && args.auto_latest
    tags << "#{args.image}:latest"
  end
  tag_args = tags.map { |t| "-t #{t}" }.join(' ')
  sh("docker build . #{tag_args}")
end
