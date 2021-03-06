# Copyright 2008 Dag Odenhall <dag.odenhall@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'amazing/widget'

module Amazing
  module Widgets
    class Gmail < Widget
      description "GMail checker"
      dependency "net/https", "Ruby standard library"
      dependency "rexml/document", "Ruby standard library"
      dependency "time", "Ruby standard library"
      option :username, "Username"
      option :password, "Password"
      option :certificates, "Path to SSL certificates", "/etc/ssl/certs"
      option :verify, "Verify certificates", false
      field :messages, "List of new messages"
      field :count, "Number of new messages"
      default { @count }

      init do
        http = Net::HTTP.new("mail.google.com", 443)
        http.use_ssl = true
        if @verify
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_path = @certificates
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new("/mail/feed/atom")
        request.basic_auth(@username, @password)
        doc = REXML::Document.new(http.request(request).body)
        begin
          @messages = doc.elements.to_a("//entry").map do |e|
            {:subject => e.elements["title"].text,
             :summary => e.elements["summary"].text,
             :from => e.elements.to_a("author").map do |a|
               {:name => a.elements["name"].text,
                :email => a.elements["email"].text}
             end[0],
             :date => Time.xmlschema(e.elements["issued"].text),
             :link => e.elements["link"].attributes["href"]}
          end
        rescue
        end
        @count = doc.root.elements["fullcount"].text.to_i
      end
    end
  end
end
