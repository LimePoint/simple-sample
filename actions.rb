Bundler.require

steps = []
20.times do |idx|
  action_name = :"action#{idx}"
  steps << action_name
  action "grand-#{idx}" do
    puts "FINDME GRANDCHILD #{idx}"
  end
  action "blah-#{idx}", steps: ["grand-#{idx}"] do
    puts "FINDME CHILD #{idx}"
    OpsChain.properties_for(:change).blah = rand(0..10) > 3 ? 7 : {}
    puts "FINDME CHILD: #{idx} -- #{OpsChain.properties_for(:change).to_json}"
  end
  action action_name, steps: ["blah-#{idx}"] do
    OpsChain.properties_for(:change).blah = {
      rand(1..100) => { a: "blah-#{rand(1..5)}" },
      rand(1..100) => { b: "blah-#{rand(1..5)}" }
    }
    puts "FINDME HERE: #{idx} -- #{OpsChain.properties_for(:change).to_json}"
    sleep rand(1..30)
  end
end

action :end do
  puts 'END'
end

action :something, steps: steps, run_as: :parallel
action :default, steps: %i[something end]
