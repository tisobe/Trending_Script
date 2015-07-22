#!/usr/bin/env /proj/sot/ska/bin/python

#########################################################################################################
#                                                                                                       #
#           extract_data.py:    extract data from mp reort and update saved data set                    #
#                                                                                                       #
#               author: t. isobe (tisobe@cfa.harvard.edu)                                               #
#                                                                                                       #
#               last update: Oct 15, 2014                                                               #
#                                                                                                       #
#########################################################################################################

import os
import sys
import re
import string
import random
import operator
import math
import numpy
from astropy.io import fits 
import unittest
#
#--- from ska
#
from Ska.Shell import getenv, bash
ascdsenv = getenv('source /home/ascds/.ascrc -r release; source /home/mta/bin/reset_param', shell='tcsh')
ascdsenv['MTA_REPORT_DIR'] = '/data/mta/Script/ACIS/CTI/Exc/Temp_comp_area/'

#
#--- reading directory list
#
path = '/data/mta/Script/Trending/house_keeping/dir_list_py'

f= open(path, 'r')
data = [line.strip() for line in f.readlines()]
f.close()

for ent in data:
    atemp = re.split(':', ent)
    var  = atemp[1].strip()
    line = atemp[0].strip()
    exec "%s = %s" %(var, line)
#
#--- append  pathes to private folders to a python directory
#
sys.path.append(bin_dir)
sys.path.append(mta_dir)
#
#--- import several functions
#
import convertTimeFormat          as tcnv       #---- contains MTA time conversion routines
import mta_common_functions       as mcf        #---- contains other functions commonly used in MTA scripts
#
#--- temp writing file name
#
rtail  = int(10000 * random.random())       #---- put a romdom # tail so that it won't mix up with other scripts space
zspace = '/tmp/zspace' + str(rtail)
#
#--- the name of data set that we want to extract
#
name_list = ['compaciscent', 'compacispwr', 'compephinkeyrates', 'compgradkodak', \
             'compsimoffset', 'gradablk', 'gradahet', 'gradaincyl', 'gradcap',    \
             'gradfap', 'gradfblk', 'gradhcone', 'gradhhflex', 'gradhpflex',      \
             'gradhstrut', 'gradocyl', 'gradpcolb', 'gradperi', 'gradsstrut',     \
             'gradtfte']

#--------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------

def extract_data(name_list):
    """
    extract the new data and update the data sets.
    Input:  name_list   --- a list of the name of dataset that we want to extract/update
    Output: updated fits file (e.g. avg_compaciscent.fits)
    """

    for dir in name_list:
#
#--- read the currently avaialble data from mp report
#
        [name_list, dom_save, data_save] = extract_new_data(dir)
        
        dlen     = len(name_list)
        dlen2    = 2 * dlen
        data_set = []
#
#--- read the already extracte data from a depository
#
        file = data_dir + '/avg_' + dir + '.fits'
        dout = fits.getdata(file, 1)
        time = dout.field('time')

        col_names = []
        for i in range(0, dlen):
            aname = name_list[i] + '_AVG'
            col_names.append(aname)
            ename = name_list[i] + '_DEV'
            col_names.append(ename)
            try:
                avg_data = dout.field(aname)
                err_data = dout.field(ename)
            except:
                avg_data = []
                err_data = []
                for j in range(0, len(time)):
                    avg_data.append(-99.0)
                    err_data.append(-99.0)

            data_set.append(avg_data)
            data_set.append(err_data)
#
#--- find the last date logged
#
        tmax = max(time)
#
#--- add all data from mp report to the saved data after the last date in the saved data set
#
        for i in range(0, len(dom_save)):
            if dom_save[i] < tmax:
                continue
            time = numpy.append(time, [dom_save[i]])
            for j in range(0, dlen2):
                data_set[j] = numpy.append(data_set[j], [data_save[j][i]])

        for i in range(0, len(time)):
            time[i] = str(int(time[i]))
#
#--- convert the data into a fits file; first time column
#
        time = numpy.array(time)
        col = fits.Column(name='Time', format='E', array=time)
        col_list = [col]
#
#--- all other column entires
#
        for j in range(0, dlen2):
            for i in range(0, len(time)):
                try:
                    val = float(data_set[j][i])
                    val = '%.3f' % round(val, 3)
                    data_set[j][i] = val 
                except:
                    data_set[j][i] = -99.0

            data_set[j] = numpy.array(data_set[j])

            col = fits.Column(name=col_names[j], format='E', array=data_set[j])
            col_list.append(col)

        cols = fits.ColDefs(col_list)
#        tbhdu = fits.BinTableHDU.from_columns(cols)            # --- version 0.42
        tbhdu = fits.new_table(cols)                            # --- version 0.30
#
#---- create a bare minimum header
#
        prihdr = fits.Header()
        prihdu = fits.PrimaryHDU(header=prihdr)
#
#--- output name. move the last one to a backup position
#
        out_name  = data_dir + '/avg_' + dir + '.fits'
        save_file = out_name + '~'
        cmd       = 'mv -f  ' + out_name + ' ' + save_file
        os.system(cmd)
#
#--- create the fits file
#
        thdulist = fits.HDUList([prihdu, tbhdu])
        thdulist.writeto(out_name)

#--------------------------------------------------------------------------------------------------------
#-- extract_new_data: read out currently available data from mp report directory                       --
#--------------------------------------------------------------------------------------------------------


def extract_new_data(dir):

    """
    read out currently available data from mp report directory
    Input:  dir     --- sub directory name where a specific data are kept
    Output: [name_list, dom_save, data_save]
                name_list   --- column name list
                dom_save    --- a list of dom for the data sets extracted
                data_save   --- a list of lists of data for each day
    """
#
#--- find available fits data
#
    cmd  = 'ls ' + mp_dir + '/*/' + dir + '/data/*_summ.fits > ' +  zspace
    os.system(cmd)
    f    = open(zspace, 'r')
    data = [line.strip() for line in f.readlines()]
    f.close()

    chk = 0
    dom_save  = []
    data_save = []
    for ent in data:
#
#--- first find time and convert it to dom
#
        atemp = re.split(mp_dir, ent)
        div   = '/' + dir
        btemp = atemp[1].replace('/', '')
        year  = btemp[0] + btemp[1] + btemp[2] + btemp[3]
        month = btemp[4] + btemp[5]
        day   = btemp[6] + btemp[7]
        year  = int(float(year))
        month = int(float(month))
        day   = int(float(day))
        
        ydate = tcnv.findYearDate(year, month, day)
        dom   = tcnv.findDOM(year, ydate, 0, 0, 0)

        if dom < 1:
            continue

        dom_save.append(int(dom))
#
#--- now open fits file and get data
#
        dout      = fits.getdata(ent, 1)
        name_list = dout.field('name')
        avg_list  = dout.field('average')
        err_list  = dout.field('error')

        dlen  = len(name_list)
        dlen2 = 2 * dlen
#
#--- at the first round, create a list; there are average and error values for
#--- each col names
#
        if chk == 0:
            chk = 1
            for i in range(0, dlen):
                avg_set = [avg_list[i]]
                err_set = [err_list[i]]
                data_save.append(avg_set)
                data_save.append(err_set)
        else:
            for i in range(0, dlen):
                apos = 2 * i
                epos = apos + 1
                data_save[apos].append(avg_list[i])
                data_save[epos].append(err_list[i])


    return [name_list, dom_save, data_save]


#-----------------------------------------------------------------------

if __name__ == "__main__":

    extract_data(name_list)


