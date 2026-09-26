Bundler.require
require 'interactor'

action :ant_hello, description: 'Echo hello with ant', step_name: "ANT hello" do
  sh 'echo ant do stuff'
end

action :ant_welcome do
  sh 'echo ant do welcome stuff'
end

action :ant_phase, steps: %i[ant_hello ant_welcome], run_as: :parallel, description: 'Run ant hello and welcome in parallel'

action :ant_with_wait, description: 'Ant with a wait step', steps: [
         :ant_hello,
         OpsChain.wait_step(seconds: 5, step_name: '5 second wait'),
         OpsChain.wait_step(step_name: 'Pause for ANT welcome'),
         :ant_welcome
       ]

action :shell_hello, description: 'Echo hello with shell' do
  result = exec_command 'bash ./hello_world.sh'
  log.info "Failed with: #{result.stderr}" if result.failed?
end

action :default, steps: %i[ant_phase shell_hello], description: 'Default action' do
  log.info "Inside default action - to test fluent-bit"
end

action :single_step_action, description: 'Single step action' do
  log.info "Hello from single step action"
end

action :multi_level_action, steps: [:child_1, :child_2, :child_4, :child_6, :child_7, :child_8, :child_9], description: 'Multi level action' do
  log.info "Hello from multi level action, inserting one extra child and appending another"
  OpsChain.child_steps = [:child_1, :child_2, :child_3, :child_4, :child_5]
end

action :child_1, description: 'my children are modified', run_as: :parallel, steps: [:grandchild_1, :grandchild_2] do
  log.info "Appending a grandchild"
  OpsChain.append_child_steps(:grandchild_3)
end

action :child_2, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_4, :grandchild_5] do
  log.info "Replacing the steps entirely with a different count"
  OpsChain.child_steps = [:grandchild_4]
end

action :child_3, description: 'my children are replaced', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  log.info "Replacing the steps with the same number, but different actions and converting to sequential"
  OpsChain.child_steps = [:grandchild_5, :grandchild_6, :grandchild_7]
  OpsChain.child_execution_strategy=:sequential
end

action :child_4, description: 'my children are removed', run_as: :parallel, steps: [:grandchild_1, :grandchild_2, :grandchild_3] do
  log.info "Now I don't have any steps"
  OpsChain.child_steps = []
end

action :child_5, description: 'my children are removed', run_as: :sequential, steps: [:grandchild_9, :grandchild_10, :grandchild_8] do
  log.info "Reordering the steps and converting to parallel"
  OpsChain.child_steps = [:grandchild_8, :grandchild_9, :grandchild_10]
  OpsChain.child_execution_strategy=:parallel
end

(6..9).each do |i|
  action "child_#{i}" do
    log.info "Not actually executed, used to test removing steps from the multi_level_action parent"
  end
end

(1..10).each do |i|
  action "grandchild_#{i}" do
    log.info "Hello from grandchild_#{i}"
    OpsChain.child_steps = [:ant_phase] if i == 5
  end
end

action :change_with_wait, description: 'Change with a wait step', steps: [:properties_1, OpsChain.wait_step, :properties_2]

action :properties_1 do
  log.info("Starting properties_1 with #{JSON.pretty_generate(OpsChain.properties)}")
  OpsChain.properties_for(:project).run_number = (OpsChain.properties.run_number || 0) + 1
  OpsChain.properties_for(:asset).current_date = Time.now
end

action :properties_2 do
  log.info("Starting properties_2 with #{JSON.pretty_generate(OpsChain.properties)}")
end

action :many_parallel, steps: (1..20).map { |i| "many_parallel_child_#{i}" }, run_as: :parallel, description: 'Lots of steps in parallel'

(1..20).each do |i|
  action "many_parallel_child_#{i}", steps: ["many_parallel_grandchild_#{i}"], run_as: :sequential
end

(1..20).each do |i|
  action "many_parallel_grandchild_#{i}", steps: %w[nested_child_1 nested_child_2], run_as: :parallel
end


(1..2).each do |i|
  action "nested_child_#{i}" do
    log.info "Hello from nested_child_#{i}"
  end
end

action :dump_context, description: 'Print the OpsChain context' do
  log.info('The Step Context JSON file is:')
  log.info(JSON.pretty_generate(JSON.parse(OpsChain::Core::StepContext.step_context_json)))
  log.info("\n\n\n\n\nThe OpsChain Context is:")
  log.info(JSON.pretty_generate(OpsChain.context))
end

action :dump_trust_store, description: 'Report whether the OpsChain trust store CAs are trusted by this action' do
  require 'openssl'

  anchors_path = '/etc/pki/ca-trust/source/anchors'
  effective_cert_file = ENV['SSL_CERT_FILE'] || OpenSSL::X509::DEFAULT_CERT_FILE
  effective_cert_dir = ENV['SSL_CERT_DIR'] || OpenSSL::X509::DEFAULT_CERT_DIR
  default_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)

  log.info("OpenSSL version: #{OpenSSL::OPENSSL_VERSION}")
  log.info("SSL_CERT_FILE: #{ENV['SSL_CERT_FILE'].inspect}, SSL_CERT_DIR: #{ENV['SSL_CERT_DIR'].inspect}")
  log.info("Compiled in default cert file: #{OpenSSL::X509::DEFAULT_CERT_FILE}, cert dir: #{OpenSSL::X509::DEFAULT_CERT_DIR}")
  log.info("Effective cert file: #{effective_cert_file} (readable: #{File.readable?(effective_cert_file)})")
  log.info("Effective cert dir: #{effective_cert_dir} (readable: #{File.readable?(effective_cert_dir)})")

  if File.readable?(effective_cert_file)
    log.info("Effective cert file holds #{File.read(effective_cert_file).scan('-----BEGIN CERTIFICATE-----').count} certificates")
  end

  uploaded_certificates = Dir.glob(File.join(anchors_path, '*')).select { |path| File.file?(path) }.sort.flat_map do |path|
    File.read(path).scan(/-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----/m).map do |pem|
      [File.basename(path), OpenSSL::X509::Certificate.new(pem)]
    end
  end

  if uploaded_certificates.empty?
    log.info("No certificates found in #{anchors_path} - nothing has been uploaded to the OpsChain trust store")
  else
    log.info("Certificates uploaded to the OpsChain trust store (from #{anchors_path}):")
    uploaded_certificates.each do |filename, certificate|
      log.info("  #{filename}: subject=#{certificate.subject}, expires=#{certificate.not_after.utc.iso8601}, trusted_by_this_action=#{default_store.verify(certificate)}")
    end
  end
end

def cp_layers_stamp(level, key)
  properties = OpsChain.properties_for(level)
  properties.layer_probe = (properties.layer_probe&.to_h || {}).merge(key => "#{key} written by the #{level} level during the action")
  properties.winner = key
  log.info("stamped #{level} with #{key}")
end

action :cp_layers_modify, description: 'Rewrite the converged properties layer probe at every database level' do
  log.info("layer_probe before the action: #{JSON.pretty_generate(OpsChain.properties.layer_probe.to_h)}")
  log.info("winner before the action: #{OpsChain.properties.winner}")

  cp_layers_stamp(:project, 'project_db_post')
  cp_layers_stamp(:environment, 'environment_db_post') if OpsChain.context.parents.include?('environment')
  cp_layers_stamp(:template, 'template_db_post') if OpsChain.context.include?('template')
  cp_layers_stamp(:template_version, 'template_version_db_post') if OpsChain.context.include?('template_version')
  cp_layers_stamp(:asset, 'asset_db_post') if OpsChain.context.parents.include?('asset')
  cp_layers_stamp(:change, 'change_db_post')
end

action :cp_layers_print, description: 'Print the converged properties layer probe' do
  log.info("layer_probe: #{JSON.pretty_generate(OpsChain.properties.layer_probe.to_h)}")
  log.info("winner: #{OpsChain.properties.winner}")
end

action :cp_layers_phases, steps: %i[cp_layers_print cp_layers_modify cp_layers_print], description: 'Print, modify, then print the converged properties layer probe'

action :modify_properties, description: 'Test updating properties' do
  OpsChain.properties_for(:project).project_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:environment).environment_current_date = Time.now.utc.iso8601 if OpsChain.context.parents.include?('environment')
  OpsChain.properties_for(:template_version).template_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:asset).asset_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:change).change_current_date = Time.now.utc.iso8601
end

child_steps = [:stop, :do_stuff, :start, :stop]
child_steps.uniq.each do |child_step|
  action child_step do
    puts "running #{child_step}"
  end
end

action :dummy_action do
  puts "running dummy action"
end

action repeated_prereqs: child_steps, description: 'repeated prereqs'
action :repeated_child, steps: child_steps, description: 'repeated child steps'
action :repeated_tree, steps: [:repeated_child, :dummy_action, :repeated_child], description: 'repeated tree'

action :failure_ignored, ignore_failure: true, description: 'test the ignore failure kwarg' do
  log.info "Before failure"
  raise "This is a failure to be ignored"
end

action :parent_of_ignore_failure, steps: [:failure_ignored], description: 'parent with an ignore failure child'

action :failing_step do
  raise "This is a failing step"
end

action :parallel_with_failing_child, steps: [:child_6, :failing_step, :failure_ignored], run_as: :parallel, ignore_failure: true, description: 'a parent with a failing child but ignoring the failure'

action :sequential_with_failing_child, steps: [:child_6, :failing_step, :failure_ignored],  ignore_failure: true, description: 'a parent with a failing child but ignoring the failure'

action :deep_tree_with_failing_children,
       run_as: :parallel,
       steps: [:sequential_with_failing_child, :input_step_change, :parallel_with_failing_child, :dummy_action],
       description: 'a deeper tree with multiple failing children but ignoring the failures'

action :input_step_change, steps: [
  :print_properties,
  :mod_properties,
  OpsChain.input_step(
    input_arguments: [
      :name,
      id: { type: :integer, path: '/input/id', default_value: 123 },
      optional_arg: { type: :array, required: false, default_value: %w[a b c] },
      boolean_arg: { path: '/my_values', type: :boolean, default_value: true},
      date_arg: { path: '/my_values', type: :date, default_value: '2024-01-01', valid_values: %w[2024-01-01 2024-12-31] },
      float_arg: { path: '/my_values', type: :float, default_value: 1234.56, valid_values: [1234.56, 7890.12] },
      arg_with_desc: { description: "an argument with a description", valid_values: %w[value1 value2 value3] },
      arg_with_default: { gui_name: "Argument With Default", default_value: "default value" }
    ],
    step_name: "Data request!"
  ),
  :print_properties
], description: 'Test that input steps can change properties'

action :mod_properties do
  OpsChain.properties_for(:project).project_current_date = Time.now.utc.iso8601
  OpsChain.properties_for(:environment).environment_current_date = Time.now.utc.iso8601 if OpsChain.context.parents.include?('environment')
  OpsChain.properties_for(:asset).asset_current_date = Time.now.utc.iso8601 if OpsChain.context.parents.include?('asset')
  OpsChain.properties_for(:template).template_current_date = Time.now.utc.iso8601 if OpsChain.context.include?('template')
  OpsChain.properties_for(:template_version).template_version_current_date = Time.now.utc.iso8601 if OpsChain.context.include?('template_version')
  OpsChain.properties_for(:change).change_current_date = Time.now.utc.iso8601
end

action :print_properties do
  log.info("Current properties are: #{JSON.pretty_generate(OpsChain.properties)}")
  log.info("Made up of: ")
  log.info("Project properties: #{JSON.pretty_generate(OpsChain.properties_for(:project))}")
  log.info("Environment properties: #{JSON.pretty_generate(OpsChain.properties_for(:environment))}") if OpsChain.context.parents.include?('environment')
  log.info("Asset properties: #{JSON.pretty_generate(OpsChain.properties_for(:asset))}") if OpsChain.context.parents.include?('asset')
  log.info("Template properties: #{JSON.pretty_generate(OpsChain.properties_for(:template))}") if OpsChain.context.include?('template')
  log.info("Template Version properties: #{JSON.pretty_generate(OpsChain.properties_for(:template_version))}") if OpsChain.context.include?('template_version')
  log.info("Change properties: #{JSON.pretty_generate(OpsChain.properties_for(:change))}")
end

class MyController
  def self.resource_type_actions = [:dummy_action]
  def self.resource_type_properties = [:cont_property, :type_property]

  def initialize(opts)
    @opts = opts
  end

  def type_property=(value)
    @opts[:type_property] = value
  end
  def cont_property = @opts[:cont_property]
  def type_property = @opts[:type_property]

  def dummy_action
    log.info "Hello from the controller action! cont_property: #{cont_property}, type_property: #{type_property}"
  end
end

resource_type :my_resource_type do
  controller MyController

  property :another_resource

  log.info "Inside resource_type my_resource_type"
end

my_resource_type :my_resource_1 do
  cont_property 'a value from the resource'
  type_property 'a value from the type'

  log.info "Inside resource my_resource_1"

end

my_resource_type :my_resource_2 do
  cont_property 'a value from the resource'
  type_property 'a value from the type'
  another_resource :my_resource_1

  action :resource_action do |res|
    log.info "Hello from the my_resource_2"
    log.info "the other resource is #{another_resource}"
    log.info "my_resource_1 is #{my_resource_1}"
    res.controller.type_property = :my_resource_1.controller
    log.info "res.controller.type_property is #{res.controller.type_property}"
  end
end

action :fred do
  puts :my_resource_1.controller
end

action "Test send_email", description: 'Ask for an email address then send an email to it', steps: [
  OpsChain.input_step(
    input_arguments: [
      email_address: { type: :string, path: '/test_email', description: 'The address to send the test email to', gui_name: 'Email Address', overwrite: true }
    ],
    step_name: 'Request email address'
  ),
  "Send email"
]

action "Send email" do
  email_address = OpsChain.properties.test_email_.email_address

  log.info "Sending a test email to #{email_address}"

  result = send_email(
    to: email_address,
    subject: "OpsChain test email from change #{OpsChain.context.change_.id}",
    body: <<~BODY,
      Hello from the simple-sample test_email action.

      Change: #{OpsChain.context.change_.id}
      Requested by: #{OpsChain.context.user_.name}
      Sent at: #{Time.now.utc.iso8601}
    BODY
    attachments: [
      { filename: 'properties.json', content: JSON.pretty_generate(OpsChain.properties), content_type: 'application/json' }
    ]
  )

  log.info "The OpsChain API returned: #{result.inspect}"
end

action :pre_req do
  log.info "I'm a prereq"
end

action "Another pre req" do
  log.info "I'm another prereq"
end

action with_pre_reqs: [:PrE_ReQ, "anoTHER pRE req"], description: 'An action with a prereq' do
  log.info "I'm the main action"
end

custom_list = OpsChain.dry_run? ? ['dry_value'] : %w[runtime_value another_runtime_value]

action "dry_run input values", description: 'Dry run values differs to actual values', steps: [
  OpsChain.input_step(
    input_arguments: [
      dry_value: { type: :string, path: '/testing', gui_name: 'Has values', overwrite: true, valid_values: custom_list }
    ]),
  :ant_welcome
] do
  log.info "Make me generate a step result"
end

action "Deploy A/B", description: 'Path separator: parent whose step name contains a /', steps: ["Run C/D", :ordinary_child]

action "Run C/D", description: 'Path separator: child whose step name contains a /', steps: [:slash_grandchild]

action :slash_grandchild, step_name: 'Grandchild E/F', description: 'Path separator: grandchild via the step_name kwarg' do
  log.info "Hello from the grandchild - my step name is #{OpsChain.context.step_.step_name.inspect}"
  log.info "My full path is #{OpsChain.context.step_.full_path.inspect}"
end

action :ordinary_child, step_name: 'Ordinary child', description: 'Path separator: sibling with no separator' do
  log.info "Hello from the ordinary child - my full path is #{OpsChain.context.step_.full_path.inspect}"
end

opschain_cli('version', run_in_dry_run: true)
opschain_cli('info', 'get')

action :cli_check, description: 'Exercise the opschain CLI from inside a step', step_name: 'OpsChain CLI check' do
  log.info "OPSCHAIN_API_URL is #{ENV['OPSCHAIN_API_URL'].inspect}"

  change = JSON.parse(opschain_cli('changes', 'get', OpsChain.context.change_.id, '-o', 'json').stdout)

  log.info "The CLI sees this change as action #{change.dig('attributes', 'action').inspect}, status #{change.dig('attributes', 'status_code').inspect}"
end

actions_rb_parsed_at = Time.now.utc.iso8601

action :report_parse_time, description: 'Reports when the actions.rb it ran from was parsed' do
  log.info "This step ran from an actions.rb parsed at #{actions_rb_parsed_at}"
  log.info "The step itself is running at #{Time.now.utc.iso8601}"
end

action :report_parse_time_reloaded, reload_actions: true, description: 'Reports the actions.rb parse time after forcing a fresh parse' do
  log.info "This step ran from an actions.rb parsed at #{actions_rb_parsed_at}"
  log.info "The step itself is running at #{Time.now.utc.iso8601}"
end

action :reload_actions_check, description: 'Compare the actions.rb parse time either side of an input step', steps: [
  :report_parse_time,
  OpsChain.input_step(
    input_arguments: [
      reload_marker: { type: :string, path: '/reload_check', gui_name: 'Reload marker', overwrite: true }
    ],
    step_name: 'Provide a reload marker'
  ),
  :report_parse_time_reloaded
]

reload_children = OpsChain.properties.dig('reload_check', 'children').to_s.split(',').map(&:strip).reject(&:empty?)

action :reload_children_parent, reload_actions: true, description: 'Children are whatever the reload_check/children property said when this actions.rb was parsed', steps: (reload_children == ['none'] ? [] : reload_children.presence || [:ant_hello]) do
  log.info "Parsed with children: #{reload_children.inspect}"
end

action :reload_children_check, description: 'A flagged stage step whose children are decided by an input step', steps: [
  OpsChain.input_step(
    input_arguments: [
      children: { type: :string, path: '/reload_check', gui_name: 'Child actions', description: 'Comma separated action names, or "none" for no children', default_value: 'ant_welcome,shell_hello', overwrite: true }
    ],
    step_name: 'Choose the child actions'
  ),
  :reload_children_parent
]

action :parallel_reload_pair, run_as: :parallel, description: 'Parallel siblings, one forked from the server and one forced to reparse', steps: [:report_parse_time, :report_parse_time_reloaded]

action :parallel_reload_check, description: 'Pause, then run the parallel reload pair', steps: [
  OpsChain.wait_step(step_name: 'Pause before the parallel pair'),
  :parallel_reload_pair
]

$reload_actions_parsed_at = Time.now.utc.iso8601(3)

class ReloadCheckController
  def initialize(opts)
    @opts = opts
  end

  def inherited_reload = OpsChain.logger.info("inherited_reload ran from an actions.rb parsed at #{$reload_actions_parsed_at}")
  def redeclared_reload = OpsChain.logger.info("redeclared_reload ran from an actions.rb parsed at #{$reload_actions_parsed_at}")
  def dsl_reload = OpsChain.logger.info("dsl_reload ran from an actions.rb parsed at #{$reload_actions_parsed_at}")
  def plain_reload = OpsChain.logger.info("plain_reload ran from an actions.rb parsed at #{$reload_actions_parsed_at}")
end

resource_type :reload_check_type do
  controller ReloadCheckController, available_actions: [
    { name: 'inherited_reload', description: 'Flagged in the controller available_actions entry', reload_actions: true },
    { name: 'redeclared_reload', description: 'Flagged only where a resource re-declares available_actions' },
    { name: 'dsl_reload', description: 'Flagged only where a resource uses the reload_actions DSL' },
    { name: 'plain_reload', description: 'Never flagged' }
  ]
end

reload_check_type :reload_inherits do
  log.info 'Inside resource reload_inherits'
end

reload_check_type :reload_redeclares do
  available_actions [
    { name: 'redeclared_reload', description: 'Flagged in this resource available_actions entry', reload_actions: true, step_name: 'Redeclared reload step' },
    { name: 'plain_reload', description: 'Never flagged' }
  ]
end

reload_check_type :reload_dsl do
  reload_actions :dsl_reload
end

# ===========================================================================
# Approval step DSL coverage
# ===========================================================================

%w[alpha bravo charlie delta].each do |probe|
  action "appr_probe_#{probe}", description: "Approval probe #{probe}" do
    log.info "Approval probe #{probe} ran at #{Time.now.utc.iso8601(3)}"
  end
end

action :appr_failing_probe, description: 'A probe that always fails' do
  raise 'appr_failing_probe always fails'
end

action :appr_user_gate, description: 'Gate on a single named user', steps: [
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[dana] }]),
  :appr_probe_bravo
]

action :appr_group_gate, description: 'Gate on a single LDAP group', steps: [
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ ldap_groups: %w[release-managers] }]),
  :appr_probe_bravo
]

action :appr_either_gate, description: 'One requirement naming a user and a group, either may approve', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[heidi], ldap_groups: %w[security-officers] }]),
  :appr_probe_alpha
]

action :appr_both_gate, description: 'Two requirements, both must be approved before the step completes', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[dana] }, { ldap_groups: %w[security-officers] }]),
  :appr_probe_alpha
]

action :appr_gate_with_children, description: 'Approval gate whose children run once it is approved', steps: [
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ ldap_groups: %w[ops-team] }], steps: %i[appr_probe_bravo appr_probe_charlie]),
  :appr_probe_delta
]

action :appr_named_gate, description: 'Approval gate with an explicit step name', steps: [
  OpsChain.approval_step(requires_approval_from: [{ ldap_groups: %w[release-managers] }], step_name: 'Change advisory board sign off'),
  :appr_probe_alpha
]

action :appr_parallel_children_gate, description: 'Approval gate wrapping a parallel children wrapper', steps: [
  OpsChain.approval_step(
    requires_approval_from: [{ user_names: %w[frank] }],
    steps: [OpsChain.steps(%i[appr_probe_alpha appr_probe_bravo], run_as: :parallel)]
  )
]

action :appr_ignore_failure_gate, description: 'Approval gate that ignores the failure of its child', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[grace] }], steps: [:appr_failing_probe], ignore_failure: true),
  :appr_probe_alpha
]

action :appr_wrapped_step, description: 'OpsChain.step nests the wrapped action beneath an approval gate', steps: [
  :appr_probe_alpha,
  OpsChain.step(:appr_probe_bravo, requires_approval_from: [{ ldap_groups: %w[ops-team] }]),
  :appr_probe_charlie
]

action :appr_wrapped_named_step, description: 'OpsChain.step with an explicit wait_step_name and two named approvers', steps: [
  OpsChain.step(:appr_probe_delta, requires_approval_from: [{ user_names: %w[dana erin] }], wait_step_name: 'Approve the delta probe')
]

action :appr_direct_attribute, description: 'An ordinary action that declares its own approvers', requires_approval_from: [{ ldap_groups: %w[dba-team] }] do
  log.info 'appr_direct_attribute ran after its approval was granted'
end

action :appr_direct_parent, description: 'Parent of the action that declares its own approvers', steps: [
  :appr_probe_alpha,
  :appr_direct_attribute,
  :appr_probe_bravo
]

action :appr_root_attribute, description: 'A change root action that declares its own approvers', requires_approval_from: [{ ldap_groups: %w[release-managers] }], steps: [:appr_probe_alpha]

action :appr_two_gates, description: 'Two sibling approval gates, both deriving the same step name', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[dana] }]),
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[erin] }]),
  :appr_probe_bravo
]

action :appr_mixed_gates, description: 'A wait step, an input step and an approval step as siblings', steps: [
  OpsChain.wait_step(step_name: 'Plain wait'),
  OpsChain.input_step(
    input_arguments: [approver_note: { type: :string, path: '/approval_check', gui_name: 'Approver note', default_value: 'none', overwrite: true }],
    step_name: 'Collect an approver note'
  ),
  OpsChain.approval_step(requires_approval_from: [{ ldap_groups: %w[release-managers] }]),
  :appr_probe_alpha
]

action :appr_unknown_identities, description: 'Names an unknown user and an unknown group alongside a real approver', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[nosuchuser dana], ldap_groups: %w[no-such-group] }]),
  :appr_probe_alpha
]

action :appr_uncached_group, description: 'Names a group that exists in the directory but is not held in the OpsChain cache', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[dana], ldap_groups: %w[auditors] }]),
  :appr_probe_alpha
]

action :appr_mixed_case, description: 'Approver names supplied in a different case to the directory', steps: [
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[DANA], ldap_groups: %w[Release-Managers] }]),
  :appr_probe_alpha
]

action :appr_nested_inner, description: 'Inner stage holding an approval gate', steps: [
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ ldap_groups: %w[security-officers] }], steps: [:appr_probe_bravo])
]

action :appr_nested_middle, description: 'Middle stage of the nested approval tree', steps: [:appr_nested_inner, :appr_probe_charlie]

action :appr_nested_outer, description: 'An approval gate three levels below the change root', steps: [:appr_nested_middle, :appr_probe_delta]

action :appr_reject_me, description: 'A gate meant to be rejected, so its children never run', steps: [
  :appr_probe_alpha,
  OpsChain.approval_step(requires_approval_from: [{ user_names: %w[erin] }], steps: %i[appr_probe_bravo appr_probe_charlie]),
  :appr_probe_delta
]

require 'digest'

module SensitiveProbe
  def self.report(logger, label, value)
    logger.info "#{label}: present=#{!value.nil?}"
    logger.info "#{label}: sha256=#{Digest::SHA256.hexdigest(value.to_s)}"
    logger.info "#{label}: still_encrypted=#{value.to_s.start_with?('{AES')}"
    logger.info "#{label}: echoed=#{value}"
  end
end

action :sens_report, description: 'Reports on the sensitive database password without revealing it' do
  SensitiveProbe.report(log, 'sens_report', OpsChain.properties.sens.db.password)
  log.info "sens_report: dump_is_ciphertext=#{OpsChain.properties.to_h.dig(:sens, :db, :password).to_s.start_with?('{AES')}"
  OpsChain.properties_for(:change).sens_touched = Time.now.utc.iso8601
end

action :sens_input_step, description: 'A sensitive input argument supplied to an input step', steps: [
  OpsChain.input_step(
    input_arguments: [
      password: { type: :sensitive, path: '/sens/db', gui_name: 'Database password', overwrite: true }
    ],
    step_name: 'Supply the database password'
  ),
  :sens_report
]

action :sens_fixed_report, description: 'Reports on the encrypted asset property without revealing it' do
  SensitiveProbe.report(log, 'sens_fixed_report', OpsChain.properties.sens.fixed.password)
end

action :sens_confirm_fixed, description: 'A sensitive input argument that must match an existing encrypted property', steps: [
  OpsChain.input_step(
    input_arguments: [
      password: { type: :sensitive, path: '/sens/fixed', gui_name: 'Confirm the password' }
    ],
    step_name: 'Confirm the fixed password'
  ),
  :sens_fixed_report
]
