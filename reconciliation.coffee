# reconciliation.coffee；

class Reconciliation
	constructor: () ->
		# 區別碼 1 byte, default 1
		# 代收代號 4 byte
		# 代收機構代號 11 byte, default: 7111111
		# 入/扣帳日期 19 byte
		# 保留欄位
		@start = 
			start_code: "1"
			collection_no: ""
			collection_org_no: ""
			charge_date: ""
			remark: ""

		# 銷帳資料
		@data = []

		# 區別碼 1 byte, default 3
		# 總金額, 15 byte, 左補0
		# 總筆數, 25 byte, 左補0
		# 保留欄位
		@end = 
			end_code: "3"
			total_amount: ""
			total_record: ""
			remark: ""

	# 新增銷帳資料
	putData: (icollect_store_no, ipos_no, ipayment_date, itx_no, itx_time, ibarcode1, ibarcode2, ibarcode3, idiff_flag) ->
		@data.push {
			collect_store_no: icollect_store_no
			pos_no: ipos_no
			payment_date: ipayment_date
			tx_no: itx_no
			tx_time: itx_time
			barcode1: ibarcode1
			barcode2: ibarcode2
			barcode3: ibarcode3
			diff_flag: idiff_flag
		}
		
module.exports = {
	Reconciliation
}