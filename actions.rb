Bundler.require

action :ant_hello do
  sh 'echo ant do stuff'
end

action :ant_welcome do
  sh 'echo ant do welcome stuff'
end

action :ant_phase, steps: %i[ant_hello ant_welcome], run_as: :parallel

action :shell_hello do
  sh 'bash ./hello_world.sh'
end

action :default, steps: %i[ant_phase shell_hello]
