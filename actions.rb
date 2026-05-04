Bundler.require

action :action_1_child_child do
  puts "FINDME HERE CHILD CHILD 1: #{OpsChain.properties_for(:change).to_json}"
end

action :action_1_child, steps: %i[action_1_child_child] do
  puts "FINDME HERE CHILD 1: #{OpsChain.properties_for(:change).to_json}"
end

action :action_1, steps: [:action_2_child] do
  sleep 5
  OpsChain.properties_for(:change).blah = { x: { a: 'b' } }
  puts "FINDME HERE 1: #{OpsChain.properties_for(:change).to_json}"
  OpsChain.properties_for(:change).blah = { child: 7 }
end

action :action_2_child_child do
  puts "FINDME HERE CHILD CHILD 2: #{OpsChain.properties_for(:change).to_json}"
end

action :action_2_child, steps: %i[action_2_child_child] do
  puts "FINDME HERE CHILD 2: #{OpsChain.properties_for(:change).to_json}"
  OpsChain.properties_for(:change).blah = { child: { b: 'x', q: 'x' } }
end

action :action_2, steps: [:action_2_child] do
  sleep 1
  OpsChain.properties_for(:change).blah = { x: { b: 'c' } }
  puts "FINDME HERE 2: #{OpsChain.properties_for(:change).to_json}"
end

action :action_3_child_child do
  puts "FINDME HERE CHILD CHILD 3: #{OpsChain.properties_for(:change).to_json}"
end

action :action_3_child, steps: %i[action_3_child_child] do
  puts "FINDME HERE CHILD 3: #{OpsChain.properties_for(:change).to_json}"
  OpsChain.properties_for(:change).blah = { child: { b: 'c' } }
end

action :action_3, steps: [:action_3_child] do
  sleep 10
  OpsChain.properties_for(:change).blah = { x: { b: 'c' } }
  puts "FINDME HERE 3: #{OpsChain.properties_for(:change).to_json}"
end


action :end do
  puts 'END'
end

action :something, steps: %i[action_1 action_2 action_3], run_as: :parallel
action :default, steps: %i[something end]
