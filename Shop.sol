pragma solidity  ^0.5.2;

contract Shop{
    string name;
    address payable pay;
    bool isInvited = false;
    bool joinProgram = false;
    IScheme bonuspt;
    
    function() payable external{}
    constructor (string memory name_in) payable public{
        name = name_in;
    }

    function makeProposal(address[] calldata shops,string calldata proposal_name,string calldata proposal_content,uint agree_vote_threshold, uint conversion_ratio, IScheme bonuspot) external returns (address)
    {
        bonuspot.setRatio(conversion_ratio);
        Proposal proposal_new = new Proposal();
        
        address payable receiver = address(proposal_new);
        receiver.transfer(0.20 ether);
        isInvited=true;
        
        return address(Proposal(proposal_new).makeProposal(shops, proposal_name, proposal_content, agree_vote_threshold, conversion_ratio));
    }

    function receiveProposalInvitation(address payable paya) external{
        pay=paya;
        isInvited=true;
    }
    
    function vote(bool myvote) external{
        require(isInvited==true,"Not invited!");
        Proposal(pay).vote(myvote);
        isInvited=false;
    }
    
    function joinBP(IScheme _bp) external{
        bonuspt = _bp;
        joinProgram= true;
    }
    
    function payBill(uint spending) external{
        if(joinProgram){
            address(bonuspt).transfer(spending);
            IScheme(bonuspt).earnPoints(address(this), spending);
        }
    }
    
    function payBillByPoints (uint _points) external returns(bool) {
        uint points =  _points/IScheme(bonuspt).getRatio();
        return IScheme(bonuspt).redeemPoints(address(this), points);
    }
}

contract Proposal{
    address payable[] shops;
    address payable[] shops_tmp;
    
    function() external payable {}
    mapping(address => uint) public voters; 
    
    string planName;
    string proposal_content;
    uint proposal_threshold;
    uint ratio;
    
    function makeProposal(
        address[] calldata  shops_in, string calldata plan_name, string calldata proposal_content_in, 
        uint proposal_threshold_in, uint ratio_in) external returns(address){
            
            planName = plan_name;
            proposal_content = proposal_content_in;
            proposal_threshold = proposal_threshold_in;
            ratio = ratio_in;

            
            for (uint i=0;i<shops_in.length;i++){
                shops_tmp.push(address(uint160(shops_in[i])));

            }
             
            for(uint i=0;i<shops_tmp.length;i++){
                bool sendSuccess = shops_tmp[i].send(1);
                require(sendSuccess!=false,"false");
                if(sendSuccess!=false){
                    shops.push(shops_tmp[i]);
                    voters[shops_tmp[i]] = 2;
                    
                    Shop(shops_tmp[i]).receiveProposalInvitation(address(this));
                }
            }
            return address(this);
     }
     
    function vote(bool agree) external{
        for(uint i=0;i<shops.length;i++){
            if(shops[i]== msg.sender){
                 
                if(agree){
                    voters[msg.sender]=1;
                }else{
                    voters[msg.sender]=0;
                }
                 
            }
        }
    }
     
    function formAgreement(IScheme bonuspt) external{
        uint cnt = 0;
        
        for(uint i=0;i<shops.length;i++){
            if(voters[shops[i]]!=2){
                cnt++;
            }
        }
        
        if(proposal_threshold<=cnt){
            for(uint i=0;i<shops.length;i++){
                if(voters[shops[i]]==1){
                    Shop(shops[i]).joinBP(bonuspt);
                }
            }
        }
    }
}

interface IScheme{
    function() external payable;
    function getRatio() external view returns(uint getratio);
    function earnPoints(address current_user, uint spending) external returns (bool status);
    function redeemPoints(address current_user, uint points) external returns (bool status);
    function setRatio(uint setratio) external;
}

contract myBonusPoints is IScheme{
    mapping (address=>uint) bonus_points_ledger;
    address[] usersbook;
    uint private conversion_ratio;
    function() external payable { }
    
    function getRatio() external view returns(uint getratio){
        return conversion_ratio;
    }
    
     function setRatio(uint setratio) external{
         conversion_ratio = setratio;
    }
    
    function earnPoints(address current_user, uint spending) external returns (bool status){
        bool newUser = true;
        bool notnewUser;
        for(uint i=0; i< usersbook.length; i++){
            if(usersbook[i]==current_user){
                newUser = false;
            }
        }
        
        uint bonus = spending/conversion_ratio;
        if(newUser){
            bonus_points_ledger[current_user] = 0;
        }
        bonus_points_ledger[current_user] = bonus_points_ledger[current_user] + bonus;
        notnewUser = !newUser;
        
        return notnewUser;
    }
    
    function redeemPoints(address current_user, uint points) external returns (bool status){
        if(bonus_points_ledger[current_user]<points){
            return false;
        }
        
        bonus_points_ledger[current_user]= bonus_points_ledger[current_user]- points;
        msg.sender.transfer(points);
        return true;
    }
}

contract User {
    string name;
    function () external payable {}
    constructor (string memory myName) public payable { name = myName; } 
    
    function pay(address payable shop_address, uint spending) external {
        shop_address.transfer(spending);
        Shop(uint160(shop_address)).payBill(spending); 
        
    }
    
    function redeem(address payable shop_address, uint points) external returns (bool status) { 
        return Shop(uint160(shop_address)).payBillByPoints(points);
    } 
}

contract TestCase {
    // warning: need lots of gas: set gas limit to 30000000 to deploy this contract. // you should have all the above contracts deployed before deploying TestCase function () external payable {}
    constructor () public payable { }
    function Test01() public payable {
        // run by a test EAO with sufficient ethers (e.g., 100 ethers)
        // make sure to trnasfer ether to this contract address before running Test01() 
        Shop s0 = new Shop("Shop 0");
        Shop s1 = new Shop("Shop 1");
        Shop s2 = new Shop("Shop 2");
        
        address(s0).transfer(0.20 ether);
        address(s1).transfer(0.10 ether);
        address(s2).transfer(0.10 ether);
        
        address[] memory partners = new address[](3);
        partners[0] = address(s0);
        partners[1] = address(s1);
        partners[2] = address(s2);
        
        IScheme myScheme = new myBonusPoints(); 
        
        address(myScheme).transfer(0.10 ether);
        
        address _p = s0.makeProposal(partners, "Joint Promotion Plan 1", "Earn Points from our Partners! Earning one point for every 8 dollars spending!", 2, 8, myScheme);
        
        address payable p = address(uint256(_p));
        
        s1.vote(false); // not join
        s2.vote(true); // join
        s0.vote(true); // join
        
        Proposal(p).formAgreement(myScheme); // p will populate Scheme
        User u0 = new User("Mary");
        User u1 = new User("John");
        address(u0).transfer(0.10 ether);
        address(u1).transfer(0.10 ether);
        u0.pay(address(s2), 2000); // user u0 spends 2000 dollars (i.e., wei) u0.redeem(address(s2), 200);
        u1.pay(address(s1), 1000); // s1 does not join the BP scheme. It can only pay by money 
    }
}