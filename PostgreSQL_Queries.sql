--->1
---> Kategorilere ve altkategorilere göre satış sayıları

SELECT 
    production.productsubcategory.productcategoryid,
	production.productcategory.name AS category,
	production.productsubcategory.name AS subcategory,
	SUM(sales.salesorderdetail.orderqty) AS numberofsales
FROM 
    production.product
JOIN production.productsubcategory
    ON production.productsubcategory.productsubcategoryid = production.product.productsubcategoryid
JOIN production.productcategory 
    ON production.productsubcategory.productcategoryid = production.productcategory.productcategoryid
JOIN sales.salesorderdetail 
    ON sales.salesorderdetail.productid = production.product.productid
GROUP BY
    production.productsubcategory.productcategoryid,
	production.productcategory.name, 
	production.productsubcategory.name 
ORDER BY 
    production.productsubcategory.productcategoryid ASC,
	SUM(sales.salesorderdetail.orderqty) DESC
	
--->2
---> En çok satış yapan 5 ürün modeli

SELECT 
    production.productsubcategory.productcategoryid, 
	production.productcategory.name AS category, 
	production.productsubcategory.name AS subcategory, 
	production.productmodel.name AS model, 
	SUM(sales.salesorderdetail.orderqty) AS numberofsales 
FROM 
    production.product
JOIN production.productsubcategory 
    ON production.productsubcategory.productsubcategoryid = production.product.productsubcategoryid
JOIN production.productcategory 
    ON production.productsubcategory.productcategoryid = production.productcategory.productcategoryid
JOIN production.productmodel 
    ON production.productmodel.productmodelid = production.product.productmodelid
JOIN sales.salesorderdetail 
    ON sales.salesorderdetail.productid = production.product.productid
GROUP BY 
    production.productsubcategory.productcategoryid, 
	production.productcategory.name, 
	production.productsubcategory.name, 
	production.productmodel.name
ORDER BY 
    SUM(sales.salesorderdetail.orderqty) DESC
LIMIT 5

--->3
---> Online satış oranı

SELECT 
    sales.salesorderheader.onlineorderflag, 
	COUNT(sales.salesorderheader.salesorderid) AS totalsales 
FROM 
    sales.salesorderheader
GROUP BY 
    sales.salesorderheader.onlineorderflag
	
--->4
---> Yıllara ve aylara göre toplam satış miktarlarının dağılımı

SELECT 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate) AS years, 
	EXTRACT(MONTH FROM sales.salesorderheader.orderdate) AS months, 
	SUM(sales.salesorderdetail.orderqty) 
FROM 
    sales.salesorderheader
JOIN sales.salesorderdetail 
    ON sales.salesorderdetail.salesorderid = sales.salesorderheader.salesorderid
GROUP BY 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate), 
	EXTRACT(MONTH FROM sales.salesorderheader.orderdate)
ORDER BY 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate) DESC, 
	EXTRACT(MONTH FROM sales.salesorderheader.orderdate) 
	
--->5
---> Çalışanların yıllara göre satış oranları ve ortalama yıllık satış oranları

CREATE FUNCTION employees_average_sales()
RETURNS TABLE(
    salespersonid INTEGER, 
	salesperson TEXT, 
	workingtime INTEGER, 
	totalsales NUMERIC, 
	averagesales NUMERIC
	) AS
$$
BEGIN
    RETURN QUERY (
	    SELECT 
		    sales.salesorderheader.salespersonid, 
			CONCAT(person.person.firstname, ' ', person.person.lastname) AS salesperson, 
			(('2015-12-06'::DATE - humanresources.employee.hiredate)/365) AS workingtime, 
			ROUND(SUM(sales.salesorderheader.totaldue),0) AS totalsales, 
			ROUND((SUM(sales.salesorderheader.totaldue)/(('2015-12-06'::DATE - humanresources.employee.hiredate)/365)),0) AS averagesales 
		FROM 
		    humanresources.employee
        JOIN person.person 
		    ON person.person.businessentityid = humanresources.employee.businessentityid
        JOIN sales.salesorderheader
		    ON person.person.businessentityid = sales.salesorderheader.salespersonid
        GROUP BY 
		    sales.salesorderheader.salespersonid, 
			CONCAT(person.person.firstname, ' ', person.person.lastname), 
			humanresources.employee.hiredate
	);
END;
$$ LANGUAGE plpgsql;

SELECT 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate) AS years, 
	sales.salesorderheader.salespersonid, 
	CONCAT(person.person.firstname, ' ', person.person.lastname) AS salesperson, 
	average.workingtime AS workingtime, 
	ROUND(SUM(sales.salesorderheader.totaldue),0) AS totalsales, 
	average.averagesales 
FROM 
    humanresources.employee
JOIN person.person 
    ON person.person.businessentityid = humanresources.employee.businessentityid
JOIN sales.salesorderheader 
    ON person.person.businessentityid = sales.salesorderheader.salespersonid
JOIN employees_average_sales() AS average 
    ON average.salespersonid = sales.salesorderheader.salespersonid
GROUP BY 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate), 
	sales.salesorderheader.salespersonid, 
	CONCAT(person.person.firstname, ' ', person.person.lastname), 
	average.workingtime, 
	humanresources.employee.hiredate, 
	average.averagesales
ORDER BY 
    sales.salesorderheader.salespersonid, 
	ROUND((SUM(sales.salesorderheader.totaldue)/(('2015-12-06'::DATE - humanresources.employee.hiredate)/365)),0) DESC
	
--->6
---> Fonksiyonla Sipariş toplamına göre müşterileri dört gruba ayıralım. (Diamond, Gold, Bronze, Silver)

CREATE FUNCTION customer_types()
RETURNS TABLE(
    customerid INTEGER, 
	territoryid INTEGER, 
	totalexpenditure NUMERIC, 
	customertype TEXT
	) AS
$$
BEGIN
    RETURN QUERY(
	    SELECT 
		    sales.salesorderheader.customerid, 
		    sales.salesorderheader.territoryid, 
		    SUM(sales.salesorderheader.totaldue) AS totalexpenditure, 
		    CASE
		        WHEN SUM(sales.salesorderheader.totaldue) > 100000 THEN 'Diamond'
			    WHEN SUM(sales.salesorderheader.totaldue) BETWEEN '9000' AND '100000' THEN 'Gold'
			    WHEN SUM(sales.salesorderheader.totaldue) BETWEEN '1000' AND '9000' THEN 'Bronze'
			    ELSE 'Silver'
		    END AS customertype
		FROM 
		    sales.salesorderheader
		JOIN sales.salesorderdetail 
		    ON sales.salesorderdetail.salesorderid = sales.salesorderheader.salesorderid
		GROUP BY 
		    sales.salesorderheader.customerid, 
			sales.salesorderheader.territoryid
		ORDER BY 
		SUM(sales.salesorderheader.totaldue) DESC);
END;
$$ LANGUAGE plpgsql;

SELECT 
    type.customertype AS customertype, 
	COUNT(type.customertype) AS numberofcustomer 
FROM 
    customer_types() AS type
GROUP BY 
    type.customertype
	
--->7
---> Sipariş sayısı dağılımı

SELECT 
    totalorders, 
	COUNT(*) AS numberofcustomer 
FROM 
   (
    SELECT
	    sales.salesorderheader.customerid, 
		COUNT(sales.salesorderheader.salesorderid) AS totalorders 
	FROM 
	    sales.salesorderheader
	GROUP BY 
	    sales.salesorderheader.customerid
   )
GROUP BY 
    totalorders
ORDER BY 
    numberofcustomer DESC
	
--->8
---> Müşterilerin tiplerinin ülkelere göre dağılımları

SELECT 
    type.customertype AS customertype, 
	type.territoryid, sales.salesterritory.name, 
	COUNT(type.customertype) AS numberofcustomer 
FROM 
    customer_types() AS type
JOIN sales.salesterritory 
    ON type.territoryid = sales.salesterritory.territoryid
GROUP BY 
    type.territoryid, 
	type.customertype, 
	sales.salesterritory.name

--->9
--->Kategorilerin gelir, maliyet ve kar hesabı

SELECT 
    production.productsubcategory.productcategoryid, 
	production.productcategory.name, 
	SUM(sales.salesorderdetail.orderqty * production.product.listprice) AS revenues, 
	SUM(sales.salesorderdetail.orderqty * production.product.standardcost) AS expenses, 
	SUM(sales.salesorderdetail.orderqty * production.product.listprice) - SUM(sales.salesorderdetail.orderqty * production.product.standardcost) AS profit 
FROM 
    sales.salesorderheader
JOIN sales.salesorderdetail 
    ON sales.salesorderdetail.salesorderid = sales.salesorderheader.salesorderid
JOIN production.product 
    ON production.product.productid = sales.salesorderdetail.productid
JOIN production.productsubcategory 
    ON production.productsubcategory.productsubcategoryid = production.product.productsubcategoryid
JOIN production.productcategory 
    ON production.productcategory.productcategoryid = production.productsubcategory.productcategoryid
GROUP BY 
    production.productsubcategory.productcategoryid, 
	production.productcategory.name
	
--->10
--->Ortalama satış sayılarına göre en çok satış yapan 5 satış personali

SELECT 
    sales.salesorderheader.salespersonid,
    CONCAT(person.person.firstname, ' ', person.person.lastname) AS salesperson,
    (('2015-12-06'::DATE - humanresources.employee.hiredate) / 365) AS workingtime,
    CAST(COUNT(sales.salesorderheader.salesorderid) AS INTEGER) AS totalorders,
    CAST(ROUND(COUNT(sales.salesorderheader.salesorderid) / (('2015-12-06'::DATE - humanresources.employee.hiredate) / 365)) AS INTEGER) AS averagesales
FROM humanresources.employee
JOIN person.person 
    ON person.person.businessentityid = humanresources.employee.businessentityid
JOIN sales.salesorderheader 
    ON person.person.businessentityid = sales.salesorderheader.salespersonid
GROUP BY 
    sales.salesorderheader.salespersonid, 
    CONCAT(person.person.firstname, ' ', person.person.lastname), 
    humanresources.employee.hiredate
ORDER BY 
    CAST(ROUND(COUNT(sales.salesorderheader.salesorderid) / (('2015-12-06'::DATE - humanresources.employee.hiredate) / 365)) AS INTEGER) DESC
LIMIT 5

--->11
---> Yıllık toplam gelir, gider ve kar miktarları 

SELECT 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate), 
	SUM(sales.salesorderheader.subtotal) AS revenues, 
	SUM(sales.salesorderdetail.orderqty * production.product.listprice) AS expenses, 
	(SUM(sales.salesorderheader.subtotal)-SUM(sales.salesorderdetail.orderqty * production.product.listprice)) AS profit 
FROM 
    sales.salesorderheader
JOIN sales.salesorderdetail 
    ON sales.salesorderdetail.salesorderid = sales.salesorderheader.salesorderid
JOIN production.product 
    ON production.product.productid = sales.salesorderdetail.productid
GROUP BY 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate)
ORDER BY 
    EXTRACT(YEAR FROM sales.salesorderheader.orderdate) DESC

	