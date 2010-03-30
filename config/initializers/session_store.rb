# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_eu_funds_session',
  :secret      => '9166f0eda3f3ce24294b0f35db0345348acb942fd87bc8024b4a0f544c1fb7ae840d96375b4fdadfab16cc63dc172258247b54f91f5358c1e4c1aa6b32c3a6e3'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
