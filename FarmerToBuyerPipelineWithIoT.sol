pragma solidity ^0.5.0;

contract WorkbenchBase {
    event WorkbenchContractCreated(string applicationName, string workflowName, address originatingAddress);
    event WorkbenchContractUpdated(string applicationName, string workflowName, string action, address originatingAddress);

    string internal ApplicationName;
    string internal WorkflowName;

    constructor(string memory applicationName, string memory workflowName) internal {
        ApplicationName = applicationName;
        WorkflowName = workflowName;
    }

    function ContractCreated() internal {
        emit WorkbenchContractCreated(ApplicationName, WorkflowName, msg.sender);
    }

    function ContractUpdated(string memory action) internal {
        emit WorkbenchContractUpdated(ApplicationName, WorkflowName, action, msg.sender);
    }
}


contract TelemetryCompliance is WorkbenchBase("TelemetryCompliance", "TelemetryCompliance")
{
    enum StateType {
        Created,
        ProvisionerBought,
        SellerAgreed,
        ProvisionerAgreed,
        TransitPending,
        InTransit,
        ReadyForSell,
        Completed,
        OutOfCompliance
    }

    StateType public State;

    address payable public Farmer;
    address payable public Seller;
    address payable public Provisioner;
    address payable public Buyer;
    address public Device;

    string public Description;
    uint public Price;
    uint public Quantity;


    uint public MinHumidity;
    uint public MaxHumidity;
    int public MinTemperature;
    int public MaxTemperature;
    uint public LastSensorUpdateTimestamp;
    uint LastHumidity;
    int LastTemperature;

    enum SensorType { Humidity, Temperature }
    bool public ComplianceStatus;
    string public ComplianceDetail;
    SensorType public ComplianceSensorType;

    constructor(uint minHumidity, uint maxHumidity, int minTemperature, int maxTemperature, uint price, uint quantity, string memory description) public
    {
        ComplianceStatus = true;
        Farmer = msg.sender;
        MinHumidity = minHumidity;
        MaxHumidity = maxHumidity;
        MinTemperature = minTemperature;
        MaxTemperature = maxTemperature;
        Price = price;
        Quantity = quantity;
        Description = description;
        State = StateType.Created;
        ComplianceDetail = "N/A";
        ContractCreated();
    }

    function Terminate() public
    {
        if (Provisioner != msg.sender || Seller != msg.sender)
        {
            revert();
        }
        State = StateType.Created;
    }

    function BuyItem(uint quantity) public
    {
        if (Buyer != msg.sender && Quantity >= quantity)
        {
            revert();
        }
        uint Sum = quantity*Price;
        Seller.transfer(Sum);
        ContractUpdated("BuyItem");
    }

    function IngestTelemetry(uint humidity, int temperature, uint timestamp) public
    {
        if (Device != msg.sender || State != StateType.InTransit)
        {
            revert();
        }

        LastHumidity = humidity;
        LastTemperature = temperature;
        LastSensorUpdateTimestamp = timestamp;

        if (humidity > MaxHumidity || humidity < MinHumidity)
        {
            ComplianceSensorType = SensorType.Humidity;
            ComplianceDetail = "Humidity value out of range.";
            ComplianceStatus = false;
        }
        else if (temperature > MaxTemperature || temperature < MinTemperature)
        {
            ComplianceSensorType = SensorType.Temperature;
            ComplianceDetail = "Temperature value out of range.";
            ComplianceStatus = false;
        }

        if (ComplianceStatus == false)
        {
            State = StateType.OutOfCompliance;
            Seller.transfer(Price*Quantity/10);
            ContractUpdated("IngestTelemetry");
        }
    }

    function MarkProvisionerBought() public
    {
        uint Sum = Price*Quantity;
        if (Provisioner != msg.sender || Provisioner.balance < Sum)
        {
            revert();
        }
        Farmer.transfer(Sum);
        Price = Price*13/10;
        ContractUpdated("MarkProvisionerBought");
    }

    function MarkAgreed() public
    {
        if (Seller != msg.sender || Provisioner != msg.sender)
        {
            revert();
        }
        if (Seller == msg.sender)
        {
            if (State == StateType.ProvisionerAgreed)
            {
                State = StateType.TransitPending;
            }
            if (State == StateType.Created)
            {
                State = StateType.SellerAgreed;
            }

        }
        if (Provisioner == msg.sender)
        {
            if (State == StateType.SellerAgreed)
            {
                State = StateType.TransitPending;
            }
            if (State == StateType.Created)
            {
                State = StateType.ProvisionerAgreed;
            }

        }
        ContractUpdated("MarkAgreed");
    }

    function MarkInTransit() public
    {
        if (Provisioner != msg.sender)
        {
            revert();
        }
        State = StateType.InTransit;
        ContractUpdated("MarkInTransit");
    }

    function MarkReadyForSell() public
    {
        if (Seller != msg.sender && State != StateType.InTransit)
        {
            revert();
        }
        uint Sum = Price*Quantity;
        Provisioner.transfer(Sum);
        State = StateType.ReadyForSell;
        Price = Price*11/10;
        ContractUpdated("MarkReadyForSell");
    }
}