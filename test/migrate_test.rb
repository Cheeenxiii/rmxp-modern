#!/usr/bin/env ruby
# Non-régression des transformations de bin/rmxp migrate.
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "rmxp"

migrate = Rmxp::Migrate.allocate
cases = {
  "case x\nwhen 0: y=1\nend\n" => "case x\nwhen 0 then y=1\nend\n",
  "case x\nwhen IO::SEEK_SET then y=1\nend\n" => "case x\nwhen IO::SEEK_SET then y=1\nend\n",
  "case x\nwhen :foo then y=1\nend\n" => "case x\nwhen :foo then y=1\nend\n",
  "def f\n  return 1\n  break\nend\n" => "def f\n  return 1\n  raise LocalJumpError, \"break outside loop\"\nend\n",
  "case x\nwhen 0: y\nend\n" => "case x\nwhen 0 then y\nend\n",
}
failures = 0
cases.each do |source, expected|
  got, = migrate.send(:transform_source, source)
  next if got == expected

  failures += 1
  puts "ECHEC\nattendu: #{expected.inspect}\nobtenu : #{got.inspect}"
end
puts failures.zero? ? "migrate: ok" : "migrate: #{failures} échec(s)"
exit(failures.zero? ? 0 : 1)
