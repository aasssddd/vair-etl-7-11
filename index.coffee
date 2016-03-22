# index.coffee
AWS = require 'aws-sdk'
Client = require('ssh2').Client
getLogger = require 'vair_log'
path = require 'path'
moment = require 'moment'
{Reconciliation} = require './reconciliation'
LineInputStream = require 'line-input-stream'
csv = require 'csv-write-stream'
fs = require 'fs'


# exports.handler = () ->
# create logger
if not process.env.NODE_ENV?
	process.env.NODE_ENV = "prod"

config = require 'app-config'

logger = getLogger(config.logger.LEVEL, {file: config.logger.FILE, path: config.logger.PATH})

# set initial param
dataTime = moment().add -1, 'day'
ftpFilePath =  "#{config.seven.FILE_PATH}/#{dataTime.format "MM"}/#{config.seven.FILE_NAME_PREFIX}.#{dataTime.format 'YYYYMMDD'}"

# get data from Seven ftp
conn = new Client()

conn.on 'error', () ->
	logger.warn "FTP connect fail"

conn.on 'ready', () ->
	logger.info "FTP ready"
	conn.sftp (conErr, sftp) ->
		if conErr? 
			logger.error "ftp connect error"
		else 
			logger.info "start reading data from #{ftpFilePath}"
			rStream = LineInputStream sftp.createReadStream(ftpFilePath, flags: "r")
			rStream.on 'error', (err) ->
				logger.warn "read file error: #{err}"
			reconcil_obj = new Reconciliation()
			rStream.setDelimiter "\r\n"
			rStream.on 'close', () ->
				logger.info "data is\n#{JSON.stringify reconcil_obj, null, 4}"
				conn.end()

				if reconcil_obj.data.length == 0
					logger.warn "no data, bye"
					return 

				writer = csv {sendHeaders: false, headers: [
					'charge_date', 'collect_store_no', 'pos_no', 'payment_date', 'tx_no', 'tx_time', 'barcode1', 'barcode2', 'barcode3', 'diff_flag'
				]}
				log_file_name = "#{reconcil_obj.start.charge_date}.csv"
				file_name = config.s3.MAIN_FILE_NAME
				writer.pipe(fs.createWriteStream file_name)
				writer.on 'finish', () ->
					logger.info "write file finish"
					AWS.config.loadFromPath = config.s3.AWS_CONFIG
					s3obj = new AWS.S3 {endpoint: "s3-us-west-2.amazonaws.com"}
					csvData = fs.createReadStream(file_name)
					csvData.on 'error', (err) ->
						logger.error "read error #{err}"
					csvData.on 'open', () ->
						s3obj.upload {Bucket: config.s3.BUCKET, Key: file_name, Body: csvData} 
						.send  (err, data) ->
							if err?
								logger.error "upload to S3 fail! #{err}"
							else
								logger.info "upload successful"
								# copy file as backup with name yyyymmdd.csv
								s3obj.copyObject {
									CopySource: config.s3.BUCKET + '/' + file_name, 
									Key: log_file_name,
									Bucket: config.s3.BUCKET
								}, (err, data) ->
									if err?
										logger.error "copy data fail: \n#{err}"

								# kill temp csv file
								fs.unlink file_name, (err) ->
									if err?
										logger.error "remove temp file fail #{err}"
				
				reconcil_obj.data.forEach (obj) ->
					obj.charge_date = reconcil_obj.start.charge_date
					writer.write obj
				writer.end()



			rStream.on 'line', (data) ->
				# parse into csv
				if data.slice(0, 1) == "1"
					# start 				
					reconcil_obj.start.collection_no = data.slice(1, 4).trim()
					reconcil_obj.start.collection_org_no = data.slice(4, 11).trim()
					reconcil_obj.start.charge_date = data.slice(11, 19).trim()
					reconcil_obj.start.remark = data.slice(-19).trim()

				else if data.slice(0, 1) == '2'
					# data
					reconcil_obj.putData data.slice(1, 7).trim(), data.slice(7, 9).trim(), data.slice(9, 17).trim(), data.slice(17, 23).trim(), data.slice(23, 27).trim(), data.slice(27, 36).trim(), data.slice(36, 68).trim(), data.slice(68, 100).trim(), data.slice(-1).trim()

				else if data.slice(0, 1) == '3'
					# end
					reconcil_obj.end.total_amount = data.slice(1, 15).trim()
					reconcil_obj.end.total_record = data.slice(15, 25).trim()
					reconcil_obj.end.remark = data.slice(-25).trim()
				else
					logger.warn "error format data: #{data}"

			return rStream.pipe process.stdout

conn.connect {
	host: config.seven.FTP_HOST,
	port: config.seven.PORT,
	username: config.seven.ACCOUNT,
	password: config.seven.PASSWORD
}
