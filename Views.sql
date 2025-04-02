-- Create SupplierPerformanceDashboard view
CREATE VIEW SupplierPerformanceDashboard AS
SELECT 
    s.SupplierID,
    s.SupplierName,
    s.Category,
    s.RiskRating,
    COUNT(DISTINCT c.ContractID) AS TotalContracts,
    SUM(c.TotalValue) AS TotalContractValue,
    CAST(AVG(p.OverallScore) AS DECIMAL(10,2)) AS AveragePerformanceScore,
    CAST(AVG(p.QualityScore) AS DECIMAL(10,2)) AS AverageQualityScore,
    CAST(AVG(p.DeliveryScore) AS DECIMAL(10,2)) AS AverageDeliveryScore,
    CAST(AVG(p.CommunicationScore) AS DECIMAL(10,2)) AS AverageCommunicationScore,
    CAST(AVG(p.CostScore) AS DECIMAL(10,2)) AS AverageCostScore,
    (SELECT COUNT(*) FROM FactPayment pm 
     JOIN DimContract ct ON pm.ContractID = ct.ContractID
     WHERE ct.SupplierID = s.SupplierID AND pm.PaymentDate > pm.DueDate) AS LatePaymentsCount
FROM 
    DimSupplier s
LEFT JOIN 
    DimContract c ON s.SupplierID = c.SupplierID
LEFT JOIN 
    FactPerformance p ON c.ContractID = p.ContractID
GROUP BY 
    s.SupplierID, s.SupplierName, s.Category, s.RiskRating;
GO

-- Create ContractPerformanceDashboard view
CREATE VIEW ContractPerformanceDashboard AS
SELECT 
    c.ContractID,
    c.ContractNumber,
    c.Description,
    s.SupplierName,
    c.StartDate,
    c.EndDate,
    c.Status,
    c.TotalValue,
    c.Department,
    c.ContractManager,
    (SELECT MAX(EvaluationDate) FROM FactPerformance WHERE ContractID = c.ContractID) AS LastEvaluationDate,
    (SELECT OverallScore FROM FactPerformance WHERE ContractID = c.ContractID AND EvaluationDate = 
        (SELECT MAX(EvaluationDate) FROM FactPerformance WHERE ContractID = c.ContractID)) AS LatestOverallScore,
    (SELECT COUNT(*) FROM FactPayment WHERE ContractID = c.ContractID AND PaymentDate > DueDate) AS LatePaymentsCount,
    (SELECT AVG(DATEDIFF(day, DueDate, PaymentDate)) FROM FactPayment 
     WHERE ContractID = c.ContractID AND PaymentDate > DueDate) AS AveragePaymentDelay,
    (SELECT COUNT(*) FROM FactContractRisk WHERE ContractID = c.ContractID AND Status IN ('Active', 'Monitored')) AS ActiveRisksCount,
    (SELECT SUM(ActualAmount) FROM FactBudgetVsActual WHERE ContractID = c.ContractID) AS TotalSpentAmount,
    CASE WHEN c.TotalValue > 0 
         THEN CAST(((SELECT SUM(ActualAmount) FROM FactBudgetVsActual WHERE ContractID = c.ContractID) / c.TotalValue * 100) AS DECIMAL(10,2))
         ELSE 0 END AS PercentageSpent
FROM 
    DimContract c
JOIN 
    DimSupplier s ON c.SupplierID = s.SupplierID;
GO

-- Create PaymentPerformanceDashboard view
CREATE VIEW PaymentPerformanceDashboard AS
SELECT 
    YEAR(p.PaymentDate) AS PaymentYear,
    MONTH(p.PaymentDate) AS PaymentMonth,
    c.Department,
    COUNT(*) AS TotalPayments,
    SUM(p.PaymentAmount) AS TotalPaymentAmount,
    SUM(CASE WHEN p.PaymentDate > p.DueDate THEN 1 ELSE 0 END) AS LatePaymentsCount,
    CAST(SUM(CASE WHEN p.PaymentDate > p.DueDate THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(10,2)) AS LatePaymentsPercentage,
    AVG(CASE WHEN p.PaymentDate > p.DueDate THEN DATEDIFF(day, p.DueDate, p.PaymentDate) ELSE 0 END) AS AverageDaysLate,
    MAX(CASE WHEN p.PaymentDate > p.DueDate THEN DATEDIFF(day, p.DueDate, p.PaymentDate) ELSE 0 END) AS MaxDaysLate
FROM 
    FactPayment p
JOIN 
    DimContract c ON p.ContractID = c.ContractID
GROUP BY 
    YEAR(p.PaymentDate), MONTH(p.PaymentDate), c.Department;
GO

-- Create ComplianceDashboard view
CREATE VIEW ComplianceDashboard AS
SELECT 
    s.SupplierID,
    s.SupplierName,
    s.Category,
    s.RiskRating,
    COUNT(DISTINCT c.DocumentType) AS DocumentTypesCount,
    SUM(CASE WHEN c.Status = 'Valid' THEN 1 ELSE 0 END) AS ValidDocumentsCount,
    SUM(CASE WHEN c.Status = 'Expired' THEN 1 ELSE 0 END) AS ExpiredDocumentsCount,
    SUM(CASE WHEN c.ExpiryDate < GETDATE() AND c.Status = 'Valid' THEN 1 ELSE 0 END) AS ExpiringInFutureDaysCount,
    SUM(CASE WHEN DATEDIFF(day, GETDATE(), c.ExpiryDate) BETWEEN 0 AND 30 AND c.Status = 'Valid' THEN 1 ELSE 0 END) AS ExpiringIn30DaysCount,
    SUM(CASE WHEN DATEDIFF(day, GETDATE(), c.ExpiryDate) BETWEEN 0 AND 60 AND c.Status = 'Valid' THEN 1 ELSE 0 END) AS ExpiringIn60DaysCount,
    SUM(CASE WHEN DATEDIFF(day, GETDATE(), c.ExpiryDate) BETWEEN 0 AND 90 AND c.Status = 'Valid' THEN 1 ELSE 0 END) AS ExpiringIn90DaysCount,
    MIN(CASE WHEN c.Status = 'Valid' THEN c.ExpiryDate ELSE NULL END) AS EarliestExpiryDate,
    MAX(c.VerificationDate) AS LastVerificationDate
FROM 
    DimSupplier s
LEFT JOIN 
    FactCompliance c ON s.SupplierID = c.SupplierID
GROUP BY 
    s.SupplierID, s.SupplierName, s.Category, s.RiskRating;
GO
