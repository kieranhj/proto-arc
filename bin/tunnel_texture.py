#!/usr/bin/python
import argparse,sys,math,arc

##########################################################################
##########################################################################

def save_file(data,path):
    if path is not None:
        with open(path,'wb') as f:
            f.write(''.join([chr(x) for x in data]))

##########################################################################
##########################################################################

def main(options):
    sw=options.screen_width or 320
    sh=options.screen_height or 256
    print 'Image width: {0} height: {1}'.format(sw,sh)

    ratio=options.ratio or 32.0
    tw=options.tex_size
    th=options.tex_size

    pixel_data=[]
    for y in range(0, sh):
        for x in range(0,sw):
            div = math.sqrt((x - sw / 2.0) * (x - sw / 2.0) + (y - sh / 2.0) * (y - sh / 2.0))
            if div != 0:
                distance = int(ratio * th / div) % th
            else:
                distance = 0

            angle = int(0.5 * tw * math.atan2(y - sh / 2.0, x - sw / 2.0) / math.pi)

            if angle < 0:
                angle = 256+angle

            pixel_data.append(angle)       # u
            pixel_data.append(distance)    # v

    #assert(len(pixel_data)==sw*sh*2)
    save_file(pixel_data,options.output_path)
    print 'Wrote {0} bytes Arc data.'.format(len(pixel_data))


##########################################################################
##########################################################################

if __name__=='__main__':
    parser=argparse.ArgumentParser()

    parser.add_argument('-o',dest='output_path',metavar='FILE',help='output ARC data to %(metavar)s')
    parser.add_argument('--ratio',type=int,help='ratio')
    parser.add_argument('--screen_width',type=int,help='screen width')
    parser.add_argument('--screen_height',type=int,help='screen height')
    parser.add_argument('tex_size',type=int,help='size of the texture')
    main(parser.parse_args())
