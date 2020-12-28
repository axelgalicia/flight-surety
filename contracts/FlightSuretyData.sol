// SPDX-License-Identifier: GPL-3.0
pragma experimental ABIEncoderV2;
pragma solidity 0.8.0;

import "./SafeMath.sol";
import "./OperationalOwnable.sol";

contract FlightSuretyData is OperationalOwnable {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address payable private authorizedAppContract;

    // Mappings
    mapping(string => Airline) private airlinesMap;
    mapping(address => bool) private isARegisteredAirlineMap;
    mapping(string => Flight) private flightsMap;

    // Arrays
    Airline[] private registeredAirlines;
    Flight[] private registeredFlights;

    enum AirlineStatus {PendingApproval, Registered, Paid}

    struct Airline {
        AirlineStatus status;
        string name;
        address ownerAddress;
        uint256 votes;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        string name;
        Airline airline;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedAppContractUpdated(address payable newAddress);

    event NewAirlineRegistered(Airline airline);

    event NewFlightRegistered(
        string airlineName,
        string flightName,
        uint256 timestamp
    );

    event TestStringValue(string value);
    event TestIntValue(uint256 value);
    event TestBooleanValue(bool value);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() {}

    /**
     * @dev Fallback function for funding smart contract.
     */
    fallback() external payable {
        fund();
    }

    receive() external payable {}

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    modifier onlyAuthorizedContract() {
        require(
            msg.sender == authorizedAppContract,
            "Caller not authorized to make this call"
        );
        _;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     *   @dev Update the authorized app contract address
     *
     */
    function updateAuthorizedAppContract(address payable newAddress)
        public
        onlyOwner
    {
        _updateAuthorizedAppContract(newAddress);
    }

    /**
     *   @dev Update the authorized app contract address
     *
     */
    function _updateAuthorizedAppContract(address payable newAddress) internal {
        require(
            newAddress != address(0),
            "The new contract address cannot be address 0"
        );
        authorizedAppContract = newAddress;
        emit AuthorizedAppContractUpdated(newAddress);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */

    function registerAirline(
        address payable airlineAddress,
        string calldata name
    ) external onlyAuthorizedContract {
        bool isConsensusRequired = _isNumberOfAirlinesFourOrMore();
        if (isConsensusRequired) {
            require(
                !_isAirlineRegisteredForAccount(airlineAddress),
                "This account has an Airline already registered"
            );
            _registerAirline(
                airlineAddress,
                name,
                AirlineStatus.PendingApproval
            );
        } else {
            require(
                isOwner(airlineAddress),
                "Only contract ownwer can register first 4 Airlines"
            );
            _registerAirline(airlineAddress, name, AirlineStatus.Registered);
        }
    }

    function _registerAirline(
        address payable airlineAddress,
        string calldata name,
        AirlineStatus status
    ) internal {
        Airline memory newAirline = Airline(status, name, airlineAddress, 0);
        airlinesMap[name] = newAirline;
        emit NewAirlineRegistered(newAirline);
        registeredAirlines.push(newAirline);
        isARegisteredAirlineMap[airlineAddress] = true;
    }

    function allAirlines() public view returns (Airline[] memory) {
        return registeredAirlines;
    }

    function allFlights() public view returns (Flight[] memory) {
        return registeredFlights;
    }

    /**
     * @dev Add new Flight
     *
     */
    function registerFlight(
        address payable airlineAddress,
        string memory airlineName,
        string memory flightName,
        uint256 flightTime
    ) external onlyAuthorizedContract {
        require(
            !_isFlightRegistered(flightName),
            "Flight name already registered"
        );

        Airline memory airline = airlinesMap[airlineName];
        require(
            airline.ownerAddress == airlineAddress,
            "Airline does not exist"
        );

        require(airline.votes >= 5, "Insufficient Votes to operate");
      
        Flight memory newFlight =
            Flight(true, 0, flightTime, flightName, airline);

        flightsMap[flightName] = newFlight;
        registeredFlights.push(newFlight);
        emit NewFlightRegistered(airline.name, flightName, flightTime);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund() public payable {}

    function _isNumberOfAirlinesFourOrMore() internal view returns (bool) {
        return registeredAirlines.length >= 4;
    }

    function isAirline(address payable airlineAddress)
        public
        view
        returns (bool)
    {
        return _isAirlineRegisteredForAccount(airlineAddress);
    }

    function _isAirlineRegisteredForAccount(address payable airlineAddress)
        internal
        view
        returns (bool)
    {
        return isARegisteredAirlineMap[airlineAddress];
    }

    function _isFlightRegistered(string memory flightName)
        internal
        view
        returns (bool)
    {
        return flightsMap[flightName].isRegistered;
    }

    function _getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
}
