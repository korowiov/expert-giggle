require 'sinatra'
require 'json'
require 'time'
require 'base64'
require 'jwt'

set :port, 3000
set :bind, '0.0.0.0'

USERS = []
JWT_SECRET = 'supersekretnyklucz123'

# ID Sequencers
$user_id_seq = 1
$task_id_seq = 1

def next_user_id
  id = $user_id_seq
  $user_id_seq += 1
  id
end

def next_task_id
  id = $task_id_seq
  $task_id_seq += 1
  id
end

# Load data from JSON
def preload_data
  file = 'data.json'
  return unless File.exist?(file)

  json = JSON.parse(File.read(file), symbolize_names: true)
  max_user_id = 0
  max_task_id = 0

  json[:users].each do |user|
    user[:id] = next_user_id
    max_user_id = [max_user_id, user[:id]].max

    user[:tasks] ||= []
    user[:tasks].each do |t|
      t[:id] = next_task_id
      t[:created_at] ||= Time.now.to_i
      max_task_id = [max_task_id, t[:id]].max
    end

    USERS << user
  end

  $user_id_seq = max_user_id + 1
  $task_id_seq = max_task_id + 1
end

preload_data

# Middleware
before do
  content_type 'application/json'
  pass if request.path_info == '/auth'

  auth_header = request.env['HTTP_AUTHORIZATION']
  unless auth_header&.start_with?('Bearer ')
    halt 401, { error: 'Missing Bearer token' }.to_json
  end

  token = auth_header.split(' ').last
  begin
    decoded = JWT.decode(token, JWT_SECRET, true, algorithm: 'HS256')
    exp = decoded[0]['exp']
    halt 401, { error: 'Token expired' }.to_json if exp && exp < Time.now.to_i

    @current_user = decoded[0]['sub']
  rescue JWT::DecodeError => e
    halt 401, { error: "Invalid token: #{e.message}" }.to_json
  end
end

# AUTH endpoint
post '/auth' do
  auth_header = request.env['HTTP_AUTHORIZATION']
  unless auth_header&.start_with?('Basic ')
    halt 401, { error: 'Unauthorized: Provide Basic Auth' }.to_json
  end

  encoded = auth_header.split(' ', 2).last
  decoded = Base64.decode64(encoded) rescue ''
  username, password = decoded.split(':', 2)

  unless username == 'admin' && password == 'secret'
    halt 401, { error: 'Invalid username or password' }.to_json
  end

  payload = {
    exp: Time.now.to_i + 3600,
    sub: 'admin'
  }

  token = JWT.encode(payload, JWT_SECRET, 'HS256')
  { token: token }.to_json
end

# USERS
get '/users' do
  USERS.map { |u| { id: u[:id], name: u[:name] } }.to_json
end

get '/users/:id' do
  user = USERS.find { |u| u[:id] == params[:id].to_i }
  halt 404 unless user
  { id: user[:id], name: user[:name] }.to_json
end

post '/users' do
  payload = JSON.parse(request.body.read) rescue {}
  name = payload['name']
  halt 422, { error: 'Name is required' }.to_json unless name

  user = { id: next_user_id, name: name, tasks: [] }
  USERS << user
  status 201
  user.to_json
end

# TASKS for user
get '/users/:id/tasks' do
  user = USERS.find { |u| u[:id] == params[:id].to_i }
  halt 404 unless user

  tasks = user[:tasks]

  if params.key?('done')
    done_val = params['done'] == 'true'
    tasks = tasks.select { |t| t[:done] == done_val }
  end

  if params.key?('created_after')
    tasks = tasks.select { |t| t[:created_at].to_i > params['created_after'].to_i }
  end

  if params.key?('created_before')
    tasks = tasks.select { |t| t[:created_at].to_i < params['created_before'].to_i }
  end

  tasks.to_json
end

post '/users/:id/tasks' do
  user = USERS.find { |u| u[:id] == params[:id].to_i }
  halt 404 unless user

  payload = JSON.parse(request.body.read) rescue {}
  halt 422, { error: 'Title is required' }.to_json unless payload['title']

  task = {
    id: next_task_id,
    title: payload['title'],
    done: payload['done'] || false,
    created_at: Time.now.to_i
  }
  user[:tasks] << task
  status 201
  task.to_json
end

get '/users/:user_id/tasks/:task_id' do
  user = USERS.find { |u| u[:id] == params[:user_id].to_i }
  halt 404 unless user
  task = user[:tasks].find { |t| t[:id] == params[:task_id].to_i }
  halt 404 unless task
  task.to_json
end

put '/users/:user_id/tasks/:task_id' do
  user = USERS.find { |u| u[:id] == params[:user_id].to_i }
  halt 404 unless user
  task = user[:tasks].find { |t| t[:id] == params[:task_id].to_i }
  halt 404 unless task

  payload = JSON.parse(request.body.read) rescue {}
  task[:title] = payload['title'] if payload.key?('title')
  task[:done] = payload['done'] unless payload['done'].nil?
  task.to_json
end

delete '/users/:user_id/tasks/:task_id' do
  user = USERS.find { |u| u[:id] == params[:user_id].to_i }
  halt 404 unless user
  index = user[:tasks].find_index { |t| t[:id] == params[:task_id].to_i }
  halt 404 unless index
  user[:tasks].delete_at(index)
  status 204
end

# GLOBAL TASKS
get '/tasks' do
  all_tasks = USERS.flat_map do |u|
    u[:tasks].map { |t| t.merge(user_id: u[:id], user_name: u[:name]) }
  end

  if params[:done]
    done = params[:done] == 'true'
    all_tasks = all_tasks.select { |t| t[:done] == done }
  end

  if params[:from]
    from_ts = params[:from].to_i
    all_tasks = all_tasks.select { |t| t[:created_at] >= from_ts }
  end

  if params[:to]
    to_ts = params[:to].to_i
    all_tasks = all_tasks.select { |t| t[:created_at] <= to_ts }
  end

  all_tasks.to_json
end

get '/tasks/:id' do
  id = params[:id].to_i

  task = nil
  USERS.each do |user|
    task = user[:tasks].find { |t| t[:id] == id }
    if task
      task = task.merge(user_id: user[:id], user_name: user[:name])
      break
    end
  end

  halt 404, { error: 'Task not found' }.to_json unless task
  task.to_json
end
