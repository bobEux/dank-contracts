pragma solidity =0.6.6;

import './interfaces/IUniswapV2Factory.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IUniswapV2Router.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';

contract UniswapV2Router is IUniswapV2Router {
    using SafeMath for uint;

    address public immutable override factory;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    event LogAddress(address logAddress);
    event LogUint(uint logUint);

    constructor(address _factory) public {
        factory = _factory;
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        bytes32 tokenHash,
        uint tokenAmountDesired,
        uint stonkAmountDesired,
        uint tokenAmountMin,
        uint stonkAmountMin
    ) internal virtual returns (uint tokenAmount, uint stonkAmount) {
        // create the pair if it doesn't exist yet
        address pair = IUniswapV2Factory(factory).getPair(tokenHash);
        if (pair == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenHash);
        }
        (uint tokenReserve, uint stonkReserve) = UniswapV2Library.getReserves(pair);
        if (tokenReserve == 0 && stonkReserve == 0) {
            (tokenAmount, stonkAmount) = (tokenAmountDesired, stonkAmountDesired);
        } else {
            uint stonkAmountOptimal = UniswapV2Library.quote(tokenAmountDesired, tokenReserve, stonkReserve);
            if (stonkAmountOptimal <= stonkAmountDesired) {
                require(stonkAmountOptimal >= stonkAmountMin, 'UniswapV2Router: INSUFFICIENT_STONK_AMOUNT');
                (tokenAmount, stonkAmount) = (tokenAmountDesired, stonkAmountOptimal);
            } else {
                uint tokenAmountOptimal = UniswapV2Library.quote(stonkAmountDesired, stonkReserve, tokenReserve);
                assert(tokenAmountOptimal <= tokenAmountDesired);
                require(tokenAmountOptimal >= tokenAmountMin, 'UniswapV2Router: INSUFFICIENT_TOKEN_AMOUNT');
                (tokenAmount, stonkAmount) = (tokenAmountOptimal, stonkAmountDesired);
            }
        }
    }
    function addLiquidity(
        bytes32 tokenHash,
        uint tokenAmountDesired,
        uint stonkAmountDesired,
        uint tokenAmountMin,
        uint stonkAmountMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint tokenAmount, uint stonkAmount, uint liquidity) {
        address stonkToken = IUniswapV2Factory(factory).stonkToken();
        emit LogAddress(stonkToken);
        address dispenser = IUniswapV2Factory(factory).dispenser();
        emit LogAddress(dispenser);
        address pair = IUniswapV2Factory(factory).getPair(tokenHash);
        emit LogAddress(pair);
        (tokenAmount, stonkAmount) = _addLiquidity(tokenHash, tokenAmountDesired, stonkAmountDesired, tokenAmountMin, stonkAmountMin);
        emit LogUint(tokenAmount);
        emit LogUint(stonkAmount);
        TransferHelper.safeTransferFromERC1155(dispenser, tokenHash, msg.sender, pair, tokenAmount);
        emit LogUint(0);
        TransferHelper.safeTransferFrom(stonkToken, msg.sender, pair, stonkAmount);
        emit LogUint(1);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }
   

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        bytes32 tokenHash,
        uint liquidity,
        uint tokenAmountMin,
        uint stonkAmountMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint tokenAmount, uint stonkAmount) {
        address pair = IUniswapV2Factory(factory).getPair(tokenHash);
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (tokenAmount, stonkAmount) = IUniswapV2Pair(pair).burn(to);
        require(tokenAmount >= tokenAmountMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(stonkAmount >= stonkAmountMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    
    function removeLiquidityWithPermit(
        bytes32 tokenHash,
        uint liquidity,
        uint tokenAmountMin,
        uint stonkAmountMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint tokenAmount, uint stonkAmount) {
        address pair = UniswapV2Library.pairFor(factory, tokenHash);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (tokenAmount, stonkAmount) = removeLiquidity(tokenHash, liquidity, tokenAmountMin, stonkAmountMin, to, deadline);
    }
   
    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swapToToken(uint amountOut, bytes32 tokenHash, address _to) internal virtual {
      address pair = IUniswapV2Factory(factory).getPair(tokenHash);
      (uint tokenAmountOut, uint stonkAmountOut) = (amountOut, uint(0));
      IUniswapV2Pair(pair).swap(
          tokenAmountOut, stonkAmountOut, _to, new bytes(0)
      );
    }

    function _swapToStonk(uint amountOut, bytes32 tokenHash, address _to) internal virtual {
      (uint tokenAmountOut, uint stonkAmountOut) = (uint(0), amountOut);
      IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenHash)).swap(
          tokenAmountOut, stonkAmountOut, _to, new bytes(0)
      );
    }

    function swapExactStonkForTokens(
      uint stonkAmountIn,
      uint tokenAmountOutMin,
      bytes32 tokenHash,
      address to,
      uint deadline
    ) external virtual override ensure(deadline) returns (uint tokenAmountOut) {
      address stonkToken = IUniswapV2Factory(factory).stonkToken();
      address pair = IUniswapV2Factory(factory).getPair(tokenHash);
      tokenAmountOut = UniswapV2Library.getTokenAmountOut(pair, stonkAmountIn);
      require(tokenAmountOut >= tokenAmountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
      TransferHelper.safeTransferFrom(
        stonkToken, msg.sender, pair, stonkAmountIn
      );
      _swapToToken(tokenAmountOut, tokenHash, to);
    }

    // TODO temporarily disabled for testing
    // function swapExactTokensForTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    //     amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    //     require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }
    // function swapTokensForExactTokens(
    //     uint amountOut,
    //     uint amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    //     amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
    //     require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }
   
    // // **** SWAP (supporting fee-on-transfer tokens) ****
    // // requires the initial amount to have already been sent to the first pair
    // function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
    //     for (uint i; i < path.length - 1; i++) {
    //         (address input, address output) = (path[i], path[i + 1]);
    //         (address token0,) = UniswapV2Library.sortTokens(input, output);
    //         IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
    //         uint amountInput;
    //         uint amountOutput;
    //         { // scope to avoid stack too deep errors
    //         (uint reserve0, uint reserve1,) = pair.getReserves();
    //         (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    //         amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
    //         amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
    //         }
    //         (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
    //         address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
    //         pair.swap(amount0Out, amount1Out, to, new bytes(0));
    //     }
    // }
    // function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    //     uint amountIn,
    //     uint amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint deadline
    // ) external virtual override ensure(deadline) {
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
    //     );
    //     uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
    //     _swapSupportingFeeOnTransferTokens(path, to);
    //     require(
    //         IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
    //         'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
    //     );
    // }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getTokenAmountOut(uint amountIn, bytes32 tokenHash)
        public
        view
        virtual
        override
        returns (uint amountOut)
    {
        address pair = IUniswapV2Factory(factory).getPair(tokenHash);
        return UniswapV2Library.getTokenAmountOut(pair, amountIn);
    }

    // TODO currently unnecessary until initial working trade is made
    // function getAmountsIn(uint amountOut, address[] memory path)
    //     public
    //     view
    //     virtual
    //     override
    //     returns (uint[] memory amounts)
    // {
    //     return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    // }
}