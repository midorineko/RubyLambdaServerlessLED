require 'json'
require 'aws-sdk-dynamodb'
require 'aws-sdk-iotdataplane'
require 'aws-sdk-iot'
require "aws-sdk"


def lambda_handler(event:, context:)
    dynamodb = Aws::DynamoDB::Client.new
    eventParams = event["queryStringParameters"]
    method = eventParams["method"]
    if method == "getThing"
        email = eventParams["email"]
        params = {
            table_name: 'LED_Hub',
            key: {
                email: email
            }
        }
        dynamodb = Aws::DynamoDB::Client.new
        results = dynamodb.get_item(params)
        print results[:item]
        { statusCode: 200, body: {things: results[:item]}.to_json}
    elsif method == "sceneSelect"
        iotdataplane = Aws::IoTDataPlane::Client.new(endpoint: 'CLIENTID')
        puts eventParams
        scene = eventParams["scene"]
        thing = eventParams["thing"]
        puts [scene, thing]
        
                
        payloadObj= { "state":
                              { "desired":
                                       {"scene":scene}
                              }
                     }
                     
        thing.split(",").each do |t|
            resp = iotdataplane.publish({
                topic: "$aws/things/"+t+"/shadow/update",
                qos: 1, # required
                payload: payloadObj.to_json # required
            })
        end
        
        { statusCode: 200, body: {selected: true}.to_json}
    elsif method == "newDevice"
        puts "we are in this one friends."
        method = eventParams["method"]
        uniq_name = eventParams["uniq_name"].gsub(/[^0-9a-z ]/i, '')
        email = eventParams["email"]
        invoke_name = eventParams["invoke_name"]
         puts [uniq_name, invoke_name, email]
         create_thing(uniq_name, invoke_name, email)
        { statusCode: 200, body: {selected: true}.to_json}
    elsif method == "updateDevices"
        method = eventParams["method"]
        # uniq_name = eventParams["uniq_name"].gsub(/[^0-9a-z ]/i, '')
        email = eventParams["email"]
        to_update_obj = JSON.parse(eventParams["to_update_obj"])
         update_things(method, to_update_obj, email)
        { statusCode: 200, body: {selected: true}.to_json}
    elsif method == "updateCustomAdminUrl"
        puts "we are in this one friends3."
        method = eventParams["method"]
        value = eventParams["value"]
        email = eventParams["email"]
        update_url(value, email)
        { statusCode: 200, body: {selected: true}.to_json}
    end
end

def update_url(value,email)
    dynamodb = Aws::DynamoDB::Client.new
    table_name = 'LED_Hub'

    params = {
        table_name: table_name,
        key: {
            email: email
        }
    }
    results = dynamodb.get_item(params)
    items = results[:item]
    puts items
    items['customAdminUrl'] = {"thing"=>value}
    
    params2 = {
        table_name: table_name,
        item: items
    }
    db_insert = dynamodb.put_item(params2)
    puts db_insert
end

def update_things(method, to_update_obj, email)
    dynamodb = Aws::DynamoDB::Client.new
    table_name = 'LED_Hub'

    params = {
        table_name: table_name,
        key: {
            email: email
        }
    }
    results = dynamodb.get_item(params)
    items = results[:item]
    
    to_update_obj.each do |k , v|
        new_invoke_name = v
        new_uniq = email + "_" + k.to_s
        uniq_name = new_uniq.gsub(/[^0-9a-z ]/i, '')
        
        items.each do |k2, v2|
            if v2['thing'] == uniq_name
                items.delete(k2)
            end
        end
        items[new_invoke_name] = {"thing"=>uniq_name}
        
    end
        params2 = {
            table_name: table_name,
            item: items
        }
        db_insert = dynamodb.put_item(params2)
        puts db_insert
end

def create_thing(uniq_name, invoke_name, email)
    iot = Aws::IoT::Client.new()
  	params = {
  	  "thing_name": uniq_name,
  	  "attribute_payload": {
  	    "attributes": {
  	      'onTheFlyCreation': "MrCatNapsCreateAThing"
  	      },
  	    "merge": true || false
  	  }
  	}
    resp = iot.create_thing(params)
    puts "thing arn"
    puts resp[:thing_arn]
    puts "thing id"
    puts resp[:thing_id]
    iam = resp[:thing_arn].split(':thing').first
    puts "iam"
    puts iam
    
    respy = iot.describe_endpoint({
      endpoint_type: "iot:Data-ATS",
    })
    endpoint = respy[:endpoint_address]
    
    #first part creates their iot and the second part inserts it into my database
    
    dynamodb = Aws::DynamoDB::Client.new
    table_name = 'LED_Hub'
    thing_url = "THINGURLS"

    params = {
        table_name: table_name,
        key: {
            email: email
        }
    }
    results = dynamodb.get_item(params)
    item = results[:item]
    
    if item
        item[invoke_name] = {"thing"=>uniq_name}
    else
        item = {}
        item[invoke_name] = {"thing"=>uniq_name}
        item['email'] = email
    end

    puts item
    params2 = {
        table_name: table_name,
        item: item
    }
    db_insert = dynamodb.put_item(params2)
    puts db_insert
end