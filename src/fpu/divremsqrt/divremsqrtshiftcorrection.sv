///////////////////////////////////////////
// divremsqrtshiftcorrection.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: shift correction
// 
// Documentation: RISC-V System on Chip Design Chapter 13
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////


module divremsqrtshiftcorrection import cvw::*;  #(parameter cvw_t P) (
  input logic  [P.NORMSHIFTSZDRSU-1:0] Shifted,                // the shifted sum before LZA correction
  // divsqrt
  input logic                     DivOp,                  // is it a divsqrt opperation
  input logic                     DivResSubnorm,          // is the divsqrt result subnormal
  input logic  [P.NE+1:0]          DivUe,                  // the divsqrt result's exponent
  input logic                     DivSubnormShiftPos,     // is the subnorm divider shift amount positive (ie not underflowed)
  //fma
  //input logic                     FmaOp,                  // is it an fma opperation
  //input logic  [P.NE+1:0]          NormSumExp,             // exponent of the normalized sum not taking into account Subnormal or zero results
  //input logic                     FmaPreResultSubnorm,    // is the result subnormal - calculated before LZA corection
  //input logic                     FmaSZero,
  // output
  //output logic [P.NE+1:0]          FmaMe,                  // exponent of the normalized sum
  output logic [P.NORMSHIFTSZDRSU-1:0] Mf,                     // the shifted sum before LZA correction
  output logic [P.NE+1:0]          Ue                      // corrected exponent for divider
);

  logic [P.NORMSHIFTSZDRSU-1:0]    CorrQm0, CorrQm1;           // portions of Shifted to select for CorrQmShifted
  logic [P.NORMSHIFTSZDRSU-1:0]    CorrQmShifted;              // the shifted divsqrt result after one bit shift
  logic                       ResSubnorm;                 // is the result Subnormal
  logic                       LZAPlus1;                   // add one or two to the sum's exponent due to LZA correction
  logic                       LeftShiftQm;                // should the divsqrt result be shifted one to the left

  // LZA correction
  assign LZAPlus1 = Shifted[P.NORMSHIFTSZDRSU-1];

  // correct the shifting error caused by the LZA
  //  - the only possible mantissa for a plus two is all zeroes 
  //      - a one has to propigate all the way through a sum. so we can leave the bottom statement alone
  //mux2 #(P.NORMSHIFTSZDRSU-2) lzacorrmux(Shifted[P.NORMSHIFTSZDRSU-3:0], Shifted[P.NORMSHIFTSZDRSU-2:1], LZAPlus1, CorrSumShifted);

  // correct the shifting of the divsqrt caused by producing a result in (2, .5] range
  //    condition: if the msb is 1 or the exponent was one, but the shifted quotent was < 1 (Subnorm)
  assign LeftShiftQm = (LZAPlus1|(DivUe==1&~LZAPlus1));
  //assign LeftShiftQm = ((DivUe==1));
  assign CorrQm0 = {Shifted[P.NORMSHIFTSZDRSU-3:0],{2'b00}};
  assign CorrQm1 = {Shifted[P.NORMSHIFTSZDRSU-2:0],{1'b0}};
  mux2 #(P.NORMSHIFTSZDRSU) divcorrmux(CorrQm0, CorrQm1, LeftShiftQm, CorrQmShifted);
  
  // if the result of the divider was calculated to be subnormal, then the result was correctly normalized, so select the top shifted bits
  always_comb
    //if(FmaOp)                       Mf = {CorrSumShifted, {P.NORMSHIFTSZDRSU-(3*P.NF+4){1'b0}}};
    //if (DivOp&~DivResSubnorm)  Mf = CorrQmShifted;
    if (~DivResSubnorm)  Mf = CorrQmShifted;
    else                       Mf = Shifted[P.NORMSHIFTSZDRSU-1:0];
    
  // Determine sum's exponent
  //  main exponent issues: 
  //      - LZA was one too large
  //      - LZA was two too large
  //      - if the result was calulated to be subnorm but it's norm and the LZA was off by 1
  //      - if the result was calulated to be subnorm but it's norm and the LZA was off by 2
  //                          if plus1                    If plus2                               kill if the result Zero or actually subnormal
  //                          |                           |                                      |
  //assign FmaMe = (NormSumExp+{{P.NE+1{1'b0}}, LZAPlus1} +{{P.NE+1{1'b0}}, FmaPreResultSubnorm}) & {P.NE+2{~(FmaSZero|ResSubnorm)}};
  
  // recalculate if the result is subnormal after LZA correction
  //assign ResSubnorm = FmaPreResultSubnorm&~Shifted[P.NORMSHIFTSZDRSU-2]&~Shifted[P.NORMSHIFTSZDRSU-1];

  // the quotent is in the range [.5,2) if there is no early termination
  // if the quotent < 1 and not Subnormal then subtract 1 to account for the normalization shift
  assign Ue = (DivResSubnorm & DivSubnormShiftPos) ? '0 : DivUe - {(P.NE+1)'(0), ~LZAPlus1};
  //assign Ue = (DivResSubnorm ) ? '0 : DivUe - {(P.NE+1)'(0), ~LZAPlus1};
endmodule
