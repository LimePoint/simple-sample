Bundler.require

puts "-------------------- #{OpsChain.properties}"

action :ant_hello do
  sh 'echo ant do stuff'
end

action :ant_welcome do
  sh 'echo ant do welcome stuff'
end

action :ant_phase, steps: %i[ant_hello ant_welcome], run_as: :parallel

action :shell_hello do
  result =exec_command 'bash ./hello_world.sh'
  OpsChain.logger.info "Failed with: #{result.stderr}" if result.failed?
end

action :default, steps: %i[ant_phase shell_hello]

