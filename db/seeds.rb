attribute_sets = [
  {
    name: 'adam',
    email: 'adam@truecoach.co'
  }
]

attribute_sets.each do |attributes|
  next if User.find_by(email: attributes[:email])

  puts "seeding #{attributes}"
  User.create!(attributes)
end
